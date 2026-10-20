// 口袋账本 · 快捷指令「识别账单」App Intent（iOS 16+，AppIntents 框架）。
//
// 作用（对标咔皮记账「识别账单」动作，2026-10-20）：
//   iOS 快捷指令流程 = 隐藏控制中心 → 等待 1 秒 → 截屏 → 从截屏获取图像
//   → 调用本动作（传入截图）。本动作把截图写入 App 容器临时目录并打上
//   就绪标记，openAppWhenRun 拉起 APP；Dart 侧（screenshot_inbox.dart）
//   在启动 / 回前台时扫描标记文件完成交接：OCR 识别 → 自动落库 → 顶部
//   通知条 → 点开账单详情。
//
// 接入步骤（已通过 project.pbxproj 注册进 Runner target，无需 Xcode 手动拖拽；
// 由 GitHub Actions 云端 macos-15 + Xcode 16 编译，下列步骤仅作说明）：
//   1. 该文件已加入 Runner target 编译清单（见 project.pbxproj 的 PBXBuildFile/PBXFileReference/PBXSourcesBuildPhase）；
//   2. 真机重新出包安装；首次在快捷指令 App 中搜索「识别账单」授权一次。
//
// 设计说明：
//   - 无需 Share Extension / App Group（AppIntents 声明在主 App target 内），
//     免签分发可用；
//   - NSTemporaryDirectory() 与 Flutter path_provider 的
//     getTemporaryDirectory() 指向同一容器目录，Dart 侧按
//     pl_pending_screenshot.jpg / pl_pending_screenshot.meta.json 两个
//     文件名交接（常量见 lib/features/ledger/data/screenshot_inbox.dart，
//     改名必须两侧同步）；
//   - 元信息文件「最后写入」作为完成标记，规避 Dart 侧读到半张图。

import AppIntents
import Foundation
import UniformTypeIdentifiers

@available(iOS 16.0, *)
struct RecognizeBillIntent: AppIntent {
    static let title: LocalizedStringResource = "识别账单"
    static let description = IntentDescription(
        "截屏识别账单并自动记入口袋账本，识别结果在 APP 顶部弹出。"
    )

    // 运行时打开 APP（对应快捷指令里的「运行时打开」开关）。
    static let openAppWhenRun: Bool = true

    // 截图参数：快捷指令中把「从截屏获取图像」接到该参数（对应「内容」）。
    @Parameter(title: "截图")
    var image: IntentFile?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let fm = FileManager.default
        let tmp = NSTemporaryDirectory()
        let imgPath = (tmp as NSString).appendingPathComponent("pl_pending_screenshot.jpg")
        let metaPath = (tmp as NSString).appendingPathComponent("pl_pending_screenshot.meta.json")

        // 清掉可能存在的旧交接文件，避免 Dart 侧误读旧图。
        try? fm.removeItem(atPath: imgPath)
        try? fm.removeItem(atPath: metaPath)

        guard let file = image else {
            return .result(
                dialog: "未收到截图，请检查快捷指令「识别账单」的截图参数是否已连接「从截屏获取图像」。"
            )
        }

        // iOS 16 可用：IntentFile.data 同步属性（data(contentType:) 仅 iOS 18+，
        // 而本 intent 标注 @available(iOS 16.0, *) 且 deployment target = 16.0）。
        // 在 iOS 18 SDK 中该属性为不可选 Data，直接取用（参数传入截图时会被填充）。
        let data = file.data
        try data.write(to: URL(fileURLWithPath: imgPath), options: Data.WritingOptions.atomic)
        let meta: [String: Any] = [
            "receivedAt": Int(Date().timeIntervalSince1970 * 1000),
        ]
        let metaData = try JSONSerialization.data(withJSONObject: meta, options: [])
        // 元信息最后写：Dart 侧以它为「截图已就绪」的完成标记。
        try metaData.write(to: URL(fileURLWithPath: metaPath), options: Data.WritingOptions.atomic)

        return .result(dialog: "收到截图，正在打开口袋账本识别…")
    }
}
