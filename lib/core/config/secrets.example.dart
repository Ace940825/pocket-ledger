/// 本地密钥模板（已提交到 git）。
///
/// 用法：复制本文件为同目录的 `secrets.dart`（该文件已被 `.gitignore` 忽略，
/// 不会提交），并填入你自己的值。口袋账本当前内置以下三项：
///
///   - [builtInOcrApiKey]   ：阿里云百炼 Qwen-VL 视觉模型 API Key（截图识别）
///   - [builtInSyncBaseUrl] ：Cloudflare Workers 同步端点
///                           形如 https://pocket-ledger.<你的子域>.workers.dev
///   - [builtInSyncToken]   ：Cloudflare Workers 访问令牌
///
/// 不填则对应功能在出包后处于「未配置」状态：
///   - 截图识别不可用（会提示内置密钥为空）
///   - 云同步默认关闭，需在设置页手动填端点与令牌
///
/// 设计：密钥编译进 app 二进制，无需 `--dart-define` 注入，也无需在设置页填写；
/// 同时因 gitignored 而不进仓库，避免公开仓库泄露。
const String builtInOcrApiKey = '';
const String builtInSyncBaseUrl = '';
const String builtInSyncToken = '';
