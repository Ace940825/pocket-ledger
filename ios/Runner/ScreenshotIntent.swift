// 口袋账本 · 快捷指令「识别账单」App Intent（iOS 16+，AppIntents 框架）。
//
// 作用（对标咔皮记账「识别账单」动作，2026-10-20 初版；2026-10-29 升级为真·不进App）：
//   iOS 快捷指令流程 = 隐藏控制中心 → 等待 1 秒 → 截屏 → 调用本动作（传入截图）。
//   本动作在后台（openAppWhenRun=false）完成：
//     1. 把截图写入 App 容器临时目录（pl_pending_screenshot.jpg + .meta.json，
//        供 Swift OCR 失败时的 Dart 兜底识别）；
//     2. 直接用 URLSession 调阿里云百炼 Qwen-VL 做 OCR（不经过 Dart / Flutter）；
//     3. 把模型原始 items 写成交接文件 pl_pending_ocr_result.json（含 image 绝对路径）；
//     4. 发结果通知（账单摘要 + 确认 / 查看 / 取消 action，category=SCREENSHOT_OCR）。
//   App 启动 / 回前台时由 Dart 侧（screenshot_inbox.dart）扫描该结果文件重建并落库；
//   确认 / 查看 action 为 .foreground，会打开 App 完成落库 / 预填（落库只能在 Dart）。
//
// 接入说明（同初版）：已通过 project.pbxproj 注册进 Runner target，无需 Xcode 手动拖拽；
// 由 GitHub Actions 云端 macos-15 + Xcode 16 编译，下列步骤仅作说明。
//
// 设计说明：
//   - 无需 Share Extension / App Group（AppIntents 声明在主 App target 内），免签可用；
//   - NSTemporaryDirectory() 与 Flutter path_provider 的 getTemporaryDirectory() 指向
//     同一容器，Swift 写、Dart 读（常量见 screenshot_inbox.dart，改名必须两侧同步）；
//   - openAppWhenRun=false：快捷指令执行时不切前台，用户只看系统通知横幅。

import AppIntents
import Foundation
import UserNotifications

/// 截图识别通知的固定 ID，Dart 侧用同一 ID 更新 / 取消通知。
let kScreenshotNotificationId = 1001

// ── 阿里云百炼 Qwen-VL（OpenAI 兼容视觉接口，大陆网络可达）──
// 端点 / 模型与 Dart 侧 ScreenshotOcrService 保持一致。
// API Key 内嵌：与 Dart 侧 builtInOcrApiKey 同一暴露级别（均编译进 app 二进制）。
let kOcrEndpoint = "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"
let kOcrModel = "qwen3-vl-plus"
let kOcrApiKey = "sk-ws-H.PRLXHHH.WLU6.MEQCIEqD0YftRRD9sAs7SGLFY9pbPxuw8_TNav8qjdW9O3UqAiBh4ffO3pHND8JgqVJRVoHOHELVjveVKxfQ9QXaxXjQAw"

/// 系统 prompt（与 Dart ScreenshotOcrService._systemPrompt 一致）。
let kOcrSystemPrompt = """
你是一个账单识别助手。用户会发送一张或多张账单 / 收据 / 交易截图。
请逐笔识别其中的交易，并只输出一个 JSON 对象：{"items":[...]}。
每个 item 的字段：
- amount：金额，数字或字符串，如 "12.50"
- direction："income"（收入）/ "expense"（支出）/ "transfer"（转账）
- category：中文分类名，如 餐饮 / 交通 / 工资 / 购物；无法确定可留空字符串
- date：交易日期，格式 "YYYY-MM-DD HH:mm" 或 "YYYY-MM-DD"
- merchant：商户名
- account：付款 / 扣款账户名，如 支付宝 / 微信 / 招商银行；转账时填转出账户
- toAccount：仅转账时填转入账户，其他情况留空字符串
- note：备注
- currency：币种代码，人民币为 "CNY"
- confidence：0~1 的识别置信度，不确定给 0.5
只输出 JSON，不要任何解释文字或 markdown 围栏。
"""

/// 用户 prompt（与 Dart ScreenshotOcrService._userPrompt 一致）。
let kOcrUserPrompt = """
请识别上面图片中的账单交易，按系统指令输出 items JSON 数组。
若某张图看不清或没有交易记录，该图不输出任何 item。
"""

@available(iOS 16.0, *)
struct RecognizeBillIntent: AppIntent {
    static let title: LocalizedStringResource = "识别账单"
    static let description = IntentDescription(
        "截屏识别账单，在通知中心确认后自动记入口袋账本。"
    )

    // 运行时不打开 App：全程在后台跑识别，用户只看系统通知横幅。
    // 落库（确认入库）是 .foreground action，会临时打开 App 一次。
    static let openAppWhenRun: Bool = false

    // 截图参数：快捷指令中把「从截屏获取图像」接到该参数（对应「内容」）。
    @Parameter(title: "截图")
    var image: IntentFile?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let fm = FileManager.default
        let tmp = NSTemporaryDirectory()
        let imgPath = (tmp as NSString).appendingPathComponent("pl_pending_screenshot.jpg")
        let metaPath = (tmp as NSString).appendingPathComponent("pl_pending_screenshot.meta.json")

        // 清掉可能存在的旧交接文件，避免 Dart 侧误读旧图 / 旧结果。
        try? fm.removeItem(atPath: imgPath)
        try? fm.removeItem(atPath: metaPath)
        try? fm.removeItem(atPath: (tmp as NSString).appendingPathComponent("pl_pending_ocr_result.json"))

        guard let file = image else {
            return .result(
                dialog: "未收到截图，请检查快捷指令「识别账单」的截图参数是否已连接「从截屏获取图像」。"
            )
        }

        // iOS 16 可用：IntentFile.data 为同步非可选属性（data(contentType:) 仅 iOS 18+）。
        let data = file.data
        try data.write(to: URL(fileURLWithPath: imgPath), options: Data.WritingOptions.atomic)
        let meta: [String: Any] = [
            "receivedAt": Int(Date().timeIntervalSince1970 * 1000),
        ]
        let metaData = try JSONSerialization.data(withJSONObject: meta, options: [])
        // 元信息最后写：Dart 侧以它为「截图已就绪」的完成标记（兜底识别路径用）。
        try metaData.write(to: URL(fileURLWithPath: metaPath), options: Data.WritingOptions.atomic)

        // 在后台直接调 OCR（不打开 App）。成功则写结果文件 + 结果通知；
        // 失败则保留 image+meta，由 App 打开时 Dart 兜底 OCR。
        if let items = await callOcr(imageData: data) {
            writeResultFile(items: items, imagePath: imgPath)
            showResultNotification(summary: summarize(items: items))
        } else {
            showFallbackNotification()
        }

        return .result(dialog: "收到截图，正在后台识别账单…")
    }

    // MARK: - OCR

    /// 调阿里云百炼 Qwen-VL；成功返回模型 items 数组，失败返回 nil。
    private func callOcr(imageData: Data) async -> [[String: Any]]? {
        guard let url = URL(string: kOcrEndpoint) else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 25
        req.setValue("Bearer \(kOcrApiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let mime = imageData.count >= 4
            && imageData[0] == UInt8(0x89) && imageData[1] == UInt8(0x50)
            && imageData[2] == UInt8(0x4E) && imageData[3] == UInt8(0x47) ? "image/png" : "image/jpeg"
        let b64 = imageData.base64EncodedString()
        let dataUri = "data:\(mime);base64,\(b64)"

        let messages: [[String: Any]] = [
            ["role": "system", "content": kOcrSystemPrompt],
            ["role": "user", "content": [
                ["type": "image_url", "image_url": ["url": dataUri]],
                ["type": "text", "text": kOcrUserPrompt],
            ]],
        ]
        let body: [String: Any] = [
            "model": kOcrModel,
            "messages": messages,
            "temperature": 0.1,
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (respData, _) = try await URLSession.shared.data(for: req)
            guard let json = try? JSONSerialization.jsonObject(with: respData) as? [String: Any] else {
                return nil
            }
            // 百炼错误形态：{"code":"...","message":"..."} 或 {"error":...}。
            if json["code"] != nil || json["error"] != nil { return nil }
            guard let choices = json["choices"] as? [[String: Any]],
                  let first = choices.first,
                  let message = first["message"] as? [String: Any],
                  let content = message["content"] as? String else { return nil }
            return extractItems(from: content)
        } catch {
            return nil
        }
    }

    /// 从模型文本稳健抽取 items 数组（兼容 markdown 围栏 / 包裹对象 / 裸数组）。
    private func extractItems(from text: String) -> [[String: Any]]? {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // 去掉 ```json ... ``` 围栏。
        if s.contains("```") {
            if let start = s.range(of: "```")?.upperBound {
                let rest = String(s[start...])
                if let end = rest.range(of: "```")?.lowerBound {
                    s = String(rest[..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }

        func parse(_ str: String) -> Any? {
            guard let d = str.data(using: .utf8) else { return nil }
            return try? JSONSerialization.jsonObject(with: d)
        }

        var decoded: Any? = parse(s)
        if decoded == nil,
           let open = s.firstIndex(where: { $0 == "{" || $0 == "[" }),
           let close = s.lastIndex(where: { $0 == "}" || $0 == "]" }),
           open < close {
            decoded = parse(String(s[open...close]))
        }

        if let arr = decoded as? [[String: Any]] { return arr }
        if let dict = decoded as? [String: Any] {
            for key in ["items", "data", "results"] {
                if let items = dict[key] as? [[String: Any]] { return items }
            }
        }
        return nil
    }

    // MARK: - 文件 / 通知

    /// 把模型原始 items 写成交接文件（Dart 侧按此重建 BillRow）。
    private func writeResultFile(items: [[String: Any]], imagePath: String) {
        let tmp = NSTemporaryDirectory()
        let resultPath = (tmp as NSString).appendingPathComponent("pl_pending_ocr_result.json")
        let payload: [String: Any] = [
            "receivedAt": Int(Date().timeIntervalSince1970 * 1000),
            "image": imagePath,
            "items": items,
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            try? data.write(to: URL(fileURLWithPath: resultPath), options: Data.WritingOptions.atomic)
        }
    }

    /// 由首笔 item 生成通知摘要（best-effort，字段缺失时回退计数）。
    private func summarize(items: [[String: Any]]) -> String {
        guard let first = items.first else { return "识别到 \(items.count) 笔账单" }
        let category = ((first["category"] as? String) ?? "").trimmingCharacters(in: .whitespaces)
        let amount: String
        if let a = first["amount"] as? String {
            amount = a
        } else if let a = first["amount"] as? NSNumber {
            amount = a.stringValue
        } else {
            amount = ""
        }
        let direction = ((first["direction"] as? String) ?? "").lowercased()
        let sign = direction.contains("income") ? "+" : (direction.contains("expense") ? "-" : "")
        if items.count == 1 {
            let title = category.isEmpty ? "截图账单" : category
            return "\(title) \(sign)\(amount)"
        }
        return "识别到 \(items.count) 笔账单"
    }

    /// 结果通知：账单摘要 + 确认 / 查看 / 取消 action（category=SCREENSHOT_OCR）。
    private func showResultNotification(summary: String) {
        let content = UNMutableNotificationContent()
        content.title = "口袋账本"
        content.body = "\(summary) · 点确认自动入账"
        content.sound = .default
        content.categoryIdentifier = "SCREENSHOT_OCR"
        addNotification(content)
    }

    /// 兜底通知：Swift OCR 失败，保留 image+meta 由 App 打开时 Dart 识别。
    private func showFallbackNotification() {
        let content = UNMutableNotificationContent()
        content.title = "口袋账本"
        content.body = "截图已收到，打开App自动识别"
        content.sound = .default
        addNotification(content)
    }

    /// 发本地通知（仅授权后；同一 id 覆盖上一条）。
    private func addNotification(_ content: UNMutableNotificationContent) {
        let request = UNNotificationRequest(
            identifier: String(kScreenshotNotificationId),
            content: content,
            trigger: nil
        )
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            center.add(request)
        }
    }
}
