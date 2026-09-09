# 在 iPhone 上免费跑起 Pocket Ledger

你已确认：**有 Apple ID，但没有付费开发者账号**。下面两条路都能做到 $0 真机运行。

---

## 方式 A（推荐，最简单）：GitHub Actions 免费签名 + AltStore / Sideloadly

CI 工作流位于 `.github/workflows/ios-build.yml`（名称 **iOS Build (Free Signing)**）。
它**先跑质量闸门**（`flutter analyze` + `dart run tool/self_check.dart`），代码不健康就
不打包，避免浪费 40 多分钟云端 mac 时间。

### 1. 触发构建

- **手动**：仓库 **Actions → iOS Build (Free Signing) → Run workflow**。
- **打 tag**：推送 `v1.0.0` 之类的 tag 会自动触发。

> 默认走「路径 A：未签名 IPA」。只有当你已经在仓库 Secrets 里放好了
> 证书与描述文件时，才勾选 `signed` 走「路径 B：已签名 IPA」。

### 2. 下载产物

构建完成后，在 workflow 的 **Artifacts** 里下载 `pocket-ledger-ios-<run号>`，
解压得到 `pocket-ledger-unsigned.ipa`。

> CI 用 `flutter build ios --release --no-codesign` 产出未签名 App，
> 再用 `ditto` 打成 IPA（保留 Frameworks 下的符号链接与扩展属性，
> 不能用普通 `zip`，否则本机重签后可能启动崩溃）。

### 3. 本机免费签名安装

任选其一（都用你的免费 Apple ID 完成「个人团队」签名）：

- **AltStore**（iPhone + 电脑端 AltServer 各装一次）：
  把 `pocket-ledger-unsigned.ipa` 用 AltStore 打开 → 自动签名安装。
- **Sideloadly**（Windows / macOS 均可，单文件工具）：
  选 IPA → 填 Apple ID → 开始，直接装到已连接的 iPhone。

首次打开前，到 iPhone **设置 → 通用 → VPN与设备管理** 信任你的开发者证书。

### 4. 续期

免费 Apple ID 签名 **7 天**后过期，App 打不开（数据不受影响）。
- AltStore：连上 AltServer 点「刷新」即可续期。
- Sideloadly：重新拖一次 IPA 重签。

> 原理：真机签名由 AltStore / Sideloadly 用你的「个人团队」证书完成，
> 全程不触发任何付费。

---

## 方式 B（有 Mac 时）：Xcode 免费签名直接装

1. 在 Mac 上 `git clone` 本项目，执行 `flutter pub get`。
2. 打开 `ios/Runner.xcworkspace`（用 Xcode）。
3. 选中 **Runner → Signing & Capabilities**：
   - Team 选你的 **Apple ID（个人团队 / Personal Team）**。
   - 把 **Bundle Identifier** 改成全球唯一，例如 `com.<你的名字>.pocketLedger`。
4. 用数据线连上 iPhone，Xcode 顶部设备选你的手机，⌘R 直接运行。
5. 首次运行需在 iPhone **设置 → 通用 → VPN与设备管理** 里信任你的开发者证书。

> 同样受 7 天限制；续期重连 Xcode 跑一次即可。若日后开通 $99/年付费开发者，
> 改为自动签名 + TestFlight，即可长期安装、免续期。

---

## 方式 C（纯 Windows，无 Mac）：借云端 Mac

Apple 要求 iOS 包必须在 macOS 环境构建。你本机是 Windows 也没关系——
上面的 **方式 A 用的是 GitHub 的 macOS 云端 runner（免费额度内）**，
本地只需能下载 artifact 并用 AltStore / Sideloadly 签名即可。

---

## 常见问题

- **Bundle ID 冲突**：方式 B 若提示 `App ID "com.example..."` 已存在，改成你自己的唯一后缀即可。
- **设备安装时提示「未受信任」**：设置 → 通用 → VPN与设备管理 → 信任开发者。
- **7 天过期**：AltStore 内刷新，或 Sideloadly 重签一次；数据不受影响。
- **CI 构建失败在质量闸门**：先本地跑 `flutter analyze` 与 `dart run tool/self_check.dart`
  修掉问题再推，别浪费云端 mac 时间。
- **想上架 App Store**：需 $99/年付费开发者账号，走 TestFlight / 审核流程（不在免费范围）。
