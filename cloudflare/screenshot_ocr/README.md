# 口袋账本 · 截图识别 Worker

把账单 / 收据截图送到 Cloudflare Workers AI 视觉模型，抽取成结构化账单，供 App 端「从截图导入」功能使用。

## 成本

- **Free 计划即可跑**：Workers AI 每天赠送 10,000 Neurons（00:00 UTC 重置），个人记账识别量远用不完，基本 **0 元/月**。
- 视觉模型 `@cf/meta/llama-3.2-vision` 在 Free 计划通常可用。若部署后返回 `403`（个别大模型限 Paid），把 `wrangler.toml` 的 `OCR_MODEL` 改小模型，或升级 Workers Paid（$5/月，仍含每天 10,000 Neurons 免费额度）。
- 截图不落盘（Worker 内存转发 → 识别 → 返回 JSON），无 R2 存储费。

## 部署

```bash
npm i -g wrangler
wrangler login
wrangler deploy          # 在本目录执行，读取 wrangler.toml
```

部署后得到地址，例如：

```
https://pocket-ledger-screenshot-ocr.<你的子域>.workers.dev
```

## App 端注入地址

构建时通过 dart-define 注入（推荐），替换 `screenshot_ocr.dart` 里的占位地址：

```bash
flutter build ios --dart-define=SCREENSHOT_OCR_ENDPOINT=https://pocket-ledger-screenshot-ocr.<子域>.workers.dev
```

（iOS 免签分发走你的既有出包流程；`image_picker` 所需相册 / 相机权限描述已在 `ios/Runner/Info.plist`。）

## 接口契约

**请求**（POST，JSON）：

```json
{ "images": ["<base64 编码的截图1>", "<base64 截图2>", "..."] }
```

**响应**（JSON）：

```json
{
  "items": [
    {
      "amount": 38.0,
      "direction": "expense",
      "category": "餐饮",
      "date": "2026-10-02",
      "merchant": "星巴克",
      "account": "微信钱包",
      "toAccount": "",
      "note": "",
      "currency": "CNY",
      "confidence": 0.92
    }
  ],
  "errors": []
}
```

- `direction`：`expense` / `income` / `transfer`（英文小写）。
- 单张识别失败不会中断整批，失败信息进 `errors`，成功项照常返回。
- 模型输出可能夹带解释文字，Worker 已做「截取 `[...]` JSON 数组 + 去 markdown 围栏」的容错。
