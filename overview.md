# 口袋账本 · 真机构建状态与下一步

## 当前状态（已验证）
- 本地三道闸门全绿（Flutter 3.24.0，与 CI 同版本）：
  - `flutter analyze` → No issues found
  - `dart run tool/self_check.dart` → 通过 87 项
  - `lib/` 与 `ios/` 中已无任何 `connectivity_plus` 残留引用
- 关键修复已推送 GitHub（origin/main 含 `2bb0eae` 删除 connectivity_plus）：
  - 移除 `connectivity_plus 7.3.1`（其 Swift 调用了 iOS 17+ 才有的
    `NWPath.isUltraConstrained`，在 iOS 13 部署目标下编译失败，且代码从未使用它）
  - 补 `ios/Podfile`（原缺失导致 `pod install` 失败）
  - 部署目标 12.0 → 13.0

## 上次构建卡 1h41m 的诊断
工作流 `timeout-minutes: 45`，真正的构建最多 45 分钟就会被 GitHub 自动杀掉。
**1h41m 的总时长是「排队等 macos-14 runner」**，不是构建卡死——GitHub 的
macOS runner 是最稀缺资源，公仓 / 免费账号经常排很久。所以：
- 看到状态 `Queued` = 在等 GitHub 分配机器，耐心等（几分钟到一小时+都有可能）
- 看到 `Running` 且某一步超过 20 分钟不动 = 才是真挂，需要看日志

## 工作流加固（commit 49be22a，待你本机 push）
1. `concurrency`：重复点 Run workflow 会自动取消上一个排队/运行中的任务，避免堆积
2. `COCOAPODS_DISABLE_STATS=1`：关掉 CocoaPods 统计上报的网络请求
3. 把 `pod install --no-repo-update` 拆成独立 step：日志里能清楚看到 pod 装了多久，
   不会和 Xcode 编译混在一起

## 你需要做的（按顺序）
### 1. 把加固提交推上 GitHub（沙箱无 GCM 凭据，必须由你本机推）
打开你的 **Git Bash / Cmder**，进入项目目录，执行：
```
git push origin main
```
（若弹浏览器就用你的 GitHub 账号登录；这是一次性授权）

### 2. 重跑构建
- 打开 https://github.com/Ace940825/pocket-ledger/actions
- 左边选 **iOS Build (Free Signing)**
- 点 **Run workflow**，`signed` 保持 `false`（未签名 IPA），确认运行
- 状态：`Queued` 是正常排队；`Running` 一般 8–15 分钟跑完
- 成功后底部 **Artifacts** 出现 `pocket-ledger-ios-<run号>.zip`

### 3. 下载并装到 iPhone 11 Pro Max（iOS 26）
- 下载 artifact zip，解压得到 `pocket-ledger-unsigned.ipa`
- Windows 装 **Sideloadly**（最新版，支持 iOS 26）
- iPhone 用原装线连电脑；Windows 需装 **Apple Devices / iTunes** 驱动识别 USB
- Sideloadly 里选该 .ipa，填你的**免费 Apple ID**，点 Start → 手机上信任开发者
  （设置 → 通用 → VPN与设备管理 → 信任）
- 打开「口袋账本」
- **7 天后过期，重签一次即可，本地数据不受影响**

## 如果重跑仍失败
贴出取消/失败前卡住的具体 Step 名或日志红字，再深挖（排查 Xcode 版本、pod、网络）。

---

# 🅲 复刻小青账 · Phase 1（统一「记一笔」面板）

> 在「完整复刻小青账」路径下完成的第一阶段：把「记一笔 / 转账」重做成
> **7-Tab 统一底部面板 + 自定义数字键盘**，并调整首页三卡顺序。

## 已交付
1. **统一记账面板** `lib/features/record/presentation/record_sheet.dart`
   - 顶部 7 Tab：支出 / 收入 / 转账 / 借还 / 报销 / 退款 / 存钱
   - 底部自定义数字键盘（1-9 + 再记 / 0 / . + 通栏保存；「再记」= 保存后不清 Tab/账户）
   - 7 种类型全部接通**既有 Repository**（不重写业务逻辑）：
     - 支出/收入/转账/退款 → `TransactionRepository`（退款用新增的 `SourceModule.refund`）
     - 借还 → `LendRepository`；报销 → `ReimbursementRepository`；存钱 → `SavingsRepository.deposit`
   - 入口：`openRecordSheet(context, initialTab: RecordTab.xxx)`
2. **首页三卡顺序** `lib/features/home/presentation/home_page.dart` → 预算剩余 → 月结余 → 净资产（含总负债/总资产）；记一笔/转账按钮改调 `openRecordSheet`
3. **核心修复** `lib/database/daos/accounts_dao.dart` → `adjustBalance` 的 `updates` 改为 `updates: {accounts}`（表访问器集合），根治「净资产不重算」Bug C
4. **枚举扩展** `lib/domain/enums.dart` → `SourceModule` 末尾追加 `refund`（append-only，安全）

## 校验
- `flutter analyze`：**0 error**（剩余 26 条为预先存在的 warning/info，不影响构建）

## 你需要做的
1. **Hot Restart**（大写 R）验证新面板 + 之前 3 个 Bug（编辑流水崩溃 / 同账户转账 / 净资产不重算）
2. 本机 `git push origin main` 推送所有本地 commit
3. 重跑 iOS Build workflow 让真机吃上修复

## Phase 2 待做
- 报销「不计入收支」开关持久化（现报销本就独立报表，开关未落库）
- 退款的 AA 付款 / 全额退款 与 自动/自定义金额 模式（现退款=金额退回指定账户）
- 首页三卡版式微调（参考图为固定堆叠，现为滑动 PageView）
- 版本统一：本地 Flutter 3.47.3 vs iOS CI 3.24.0 分裂

---

# 🅴 复刻小青账 · 记一笔键盘交互修复（2026-09-11）

## 本次交付
按用户新发 3 张截图修复「记一笔」支出/收入页键盘交互：

1. **系统键盘弹出后点击金额可切回数字键盘**
   - `record_sheet.dart` `_buildInlineAmount()` 金额文本改为 `Expanded + GestureDetector`
   - onTap 先调用 `FocusManager.instance.primaryFocus?.unfocus()` 收起系统键盘，再展开自定义数字键盘
   - 折叠键同样改用 `FocusManager` 收起系统键盘，避免焦点冲突

2. **移除金额旁 X 删除按钮**
   - 删除逻辑统一走键盘右侧「删除」键
   - 避免金额行拥挤、与小青账参考一致

3. **稳定「记一笔」面板高度**
   - 面板高度改用 `MediaQuery.sizeOf(context).height * 0.92`，不随系统键盘弹出/收起而重建
   - 底部 padding 改用 `MediaQuery.viewInsetsOf(context).bottom`，精确监听键盘高度
   - 键盘区底部安全区仍使用 `MediaQuery.viewPaddingOf(context).bottom` 避手势条

## 校验
- `flutter analyze`：**0 error**（warning/info 为既有）
- `flutter test`：**212/212 passed**
- `flutter build bundle --debug -v`：**FL_EXIT=0**
- `dart run tool/self_check.dart`：**87/87 通过**

## 提交
- commit `0f52433` fix(record_sheet): 小青账支出页键盘交互修复

---

# 🅳 复刻小青账 · 账户页模板补齐（2026-09-11）

## 本次交付
按用户新发的 3 张截图继续对齐小青账「新建账户」表单：

1. **应收-借出** (`AccountType.lend`)
   - 基本信息：`借款给谁` + `借出金额`（计算器图标）
   - 余额同步：`同时记一笔账单` 开关，默认开启 + 说明文案
   - 其他：资产状态（使用中/隐藏/封存）+ 计入总资产
2. **应收-报销** (`AccountType.reimbursement`)
   - 基本信息：仅 `用户名`
   - 无余额同步、无资金卡片
3. **应付-借入** (`AccountType.borrow`)
   - 基本信息：`向谁借` + `借入金额`
   - 余额同步默认开启
4. **借记卡** (`AccountType.bankCard`)
   - 点进借记卡与信用卡一致：先进入 `BankSelectPage` 选择开户银行
   - 表单顶部显示所选银行，保留账户名称/备注/卡号/余额
5. **银行选择页** (`bank_select_page.dart`)
   - 支持 `title` 参数；当前统一显示为「选择银行」

## 关键文件
- `lib/features/accounts/presentation/account_form_page.dart`
- `lib/features/accounts/presentation/add_account_page.dart`
- `lib/features/accounts/presentation/bank_select_page.dart`
- `test/features/accounts/add_account_page_test.dart`

## 校验
- `flutter analyze`：0 error（仅预先存在的 info/warning）
- `flutter test`：212/212 通过
- `flutter build bundle --debug -v`：EXIT=0
- `dart run tool/self_check.dart`：87/87 通过

---

# 🅴 复刻小青账 · 记一笔支出页布局改造（2026-09-11）

## 本次交付
按小青账截图把「记一笔」面板中的 **支出 / 收入** Tab 改为小青账风格布局：

1. **分类图标网格**（`record_sheet.dart` 新布局）
   - 一级分类用「图标 + 文字」5 列网格展示。
   - 每个分类右上角保留「···」更多入口（后续可扩展编辑 / 删除 / 添加子分类）。
   - 最后一格固定「设置」，点击跳转分类管理页。
2. **二级分类底部面板**
   - 点击有一级分类时弹出底部面板，显示该分类下的二级分类（Chip 形式）。
   - 支持「添加」占位按钮。
3. **功能键行**
   - 横向滚动的功能键：账户、报销、优惠、图片、标签、不计入、模板。
   - 账户点击弹出账户选择面板；报销 / 不计入可切换激活状态；其余功能暂为 UI 占位。
4. **金额 + 日期 + 备注**
   - 金额显示在功能键下方，支出红色 / 收入绿色。
   - 日期与备注在同一行，点击日期可调日期选择器。
5. **可折叠底部键盘**
   - 左侧 3 列数字 + 再记 / 0 / . + 通栏保存。
   - 右侧独立「删除 / 折叠」按钮；折叠后底部只显示金额条，点击可展开。
6. **其余 Tab 保持原布局**
   - 转账 / 借还 / 报销 / 退款 / 存钱继续使用原 ListView + 底部键盘。

## 关键文件
- `lib/features/record/presentation/record_sheet.dart`
- `lib/features/record/widgets/amount_keypad.dart`（未改动，旧布局复用）

## 校验
- `flutter analyze`：0 error / 0 warning（剩余 65 条既有 info）
- `flutter test`：212/212 通过
- `flutter build bundle --debug -v`：EXIT=0
- `dart run tool/self_check.dart`：87/87 通过

## 19:44 修复支出页白屏卡死

用户真机反馈：记一笔支出页只显示顶部 Tab，主体空白且卡死无法切换。

**根因**：`_RecordKeypad` 使用 `IntrinsicHeight` 包裹 `Row`，右侧固定宽度的
`Column` 内放两个 `Expanded`。`Expanded` 要求父 `Column` 高度确定，而 `Column`
高度又依赖 `IntrinsicHeight` 测量 `Row` 高度，形成循环约束，布局系统无法 laid out。

**修法**：`_RecordKeypad` 改为固定高度 `260` 的 `SizedBox`；左侧数字区 `GridView`
用 `Expanded` 填满剩余空间；右侧 56 宽 `Column` 保持两个 `Expanded` 均分固定高度。
折叠状态本身固定 56 高度，不受影响。

验证：四道关卡全绿（analyze / test 212/212 / build EXIT=0 / self_check 87/87）。

## 20:07 修复备注双键盘冲突与底部导航栏透出问题

用户真机反馈：
- 点备注输入时系统键盘与自定义数字键盘同时显示，互相遮挡。
- 记一笔面板后方仍能看到主页面的底部导航栏。

**根因**：
1. 备注 `TextField` 未监听焦点，获取焦点时没有收起自定义键盘。
2. `showModalBottomSheet` 默认 `useRootNavigator: false`，modal 插入当前页面
   Navigator，主页面的 `Scaffold.bottomNavigationBar` 仍绘制在 modal 下方。

**修法**：
- `record_sheet.dart` 新增 `_noteFocusNode`，focus 时自动收起自定义键盘
  (`_keyboardExpanded = false`)，并把 `focusNode` 绑到备注 `TextField`。
- `openRecordSheet` 增加 `useRootNavigator: true`，让 modal 覆盖全屏底部导航栏。

验证：四道关卡全绿（analyze / test 212/212 / build EXIT=0 / self_check 87/87）。

## 21:10 修复备注与自定义键盘折叠/展开冲突

用户真机反馈：备注输入后点击折叠/展开，系统键盘与自定义数字键盘仍会同时显示。

**根因**：只处理了「备注获取焦点时收起自定义键盘」，未处理反向流程：
系统键盘已弹出、备注仍有焦点时，点击金额条上的向上箭头展开自定义键盘，
没有主动 unfocus 备注，系统键盘继续显示，导致双键盘叠加。

**修法**：
- 折叠条 `onTap`（展开自定义键盘）先执行 `FocusScope.of(context).unfocus()`，
  再 `setState(_keyboardExpanded = true)`。
- 备注 `TextField` 增加 `onTapOutside: (_) => FocusScope.of(context).unfocus()`，
  点击备注区域外部时自动收起系统键盘。

验证：四道关卡全绿（analyze / test 212/212 / build EXIT=0 / self_check 87/87）。

## 21:28 按小青账截图调整键盘布局

用户发小青账键盘参考图：4×4 网格，右侧列 = 删除 / - / + / 保存，
底部行 = 再记 / 0 / . / 保存；并要求把折叠键移到金额条右侧。

**修法**：
- `_RecordKeypad` 改为 4×4 `GridView`：
  - 1-3 + 删除，4-6 + -，7-9 + +，再记/0/./保存
  - 高度 260，间距 8，移除原右侧删除/折叠双栏
- `_KeyAction` 新增 `showLabel` 参数，`-` / `+` 只显示图标
- 折叠功能从键盘右侧移到金额条右侧：
  - 展开状态：金额条右侧显示向下箭头，点击折叠
  - 折叠状态：底部金额条右侧显示向上箭头，点击展开
- 清空金额按钮移到金额左侧，仅在金额非空时显示

验证：四道关卡全绿（analyze / test 212/212 / build EXIT=0 / self_check 87/87）。

## 21:36 固定金额/备注与键盘间距 + 键盘按键加边框

用户真机反馈：金额栏、备注栏与键盘间距被挤压，且键盘按键没有边框。

**修法**：
- `record_sheet.dart`：把 `_buildInlineAmount()` 与 `_buildDateNoteRow()` 从
  `SingleChildScrollView` 中移出，固定在键盘上方，使用 `AppDimens.spaceMd`
  作为固定间距，分类网格滚动不再挤压金额/备注区。
- `_Digit` 与 `_KeyAction` 外包 `Container`，加 `Border.all(color: AppColors.divider)`
  与圆角边框，按键视觉与小青账截图一致。

验证：四道关卡全绿（analyze / test 212/212 / build EXIT=0 / self_check 87/87）。

## 22:01 修复顶部贴顶、键盘底部安全区与键盘显隐冲突

用户真机反馈三张截图：
1. 「记一笔」标题栏上方紧贴状态栏，没有安全间距。
2. 底部自定义键盘最下一行被系统手势条压住，边界显示不完整。
3. 点备注唤起系统键盘后，自定义数字键盘应完全隐藏；点金额栏应重新唤起数字键盘。

**修法**（均位于 `record_sheet.dart`）：
1. 顶部标题 Padding 增加 `MediaQuery.paddingOf(context).top`，避免贴到状态栏。
2. `_buildCollapsibleKeypad` 底部 padding 增加 `MediaQuery.viewPaddingOf(context).bottom`，
   展开键盘与折叠条都留出系统手势条/导航条安全区。
3. `_buildCategoryAccountBody` 增加判断：当系统键盘弹出（`viewInsets.bottom > 0`）
   且备注输入框有焦点时，不渲染自定义键盘/折叠条，避免与系统键盘同时出现。
4. `_buildInlineAmount` 的金额文字外包 `GestureDetector`，点击时先 `unfocus` 备注，
   再展开自定义数字键盘。

验证：四道关卡全绿（analyze / test 212/212 / build EXIT=0 / self_check 87/87）。

## 2026-09-14 09:06 小青账键盘 +/- 运算符生效 + 外框圆角 + 按键矮宽

用户三张截图反馈：键盘里的「-」「+」只是视觉占位无功能；要求键盘外框改圆角、
四周保留留白；按键上下压缩、左右拉长；行列与按键间等距均匀。

**修法**（均位于 `record_sheet.dart`）：
1. **运算符功能化**：
   - `_RecordSheetState` 增加 `_pendingAmount` / `_pendingOperator`。
   - 新增 `_onOperator`：连续输入时先结算上一轮 pending，再挂起新运算符；
     保存时 `_effectiveAmount` 自动计算结果（基于整数「分」运算，避免浮点误差）。
   - `_save` 成功后清空 pending，避免影响下一笔。
   - `_RecordKeypad` 增加 `onOperator` 回调，「-」「+」键从 `onTap: null` 改为触发运算。
2. **键盘外框圆角留白**：
   - `_buildCollapsibleKeypad` 的 Container 改为完整 `Border.all` + `radiusLg` 圆角，
     四周 `margin: spaceMd`，内部 `padding: spaceMd`，从贴边直线条变成悬浮圆角面板。
3. **按键矮宽与等距**：
   - `_RecordKeypad` GridView：`height 260 → 196`，`childAspectRatio 1.45 → 2.0`，
     `crossAxisSpacing` / `mainAxisSpacing` 统一为 `AppDimens.spaceSm`。

验证：四道关卡全绿（analyze 0 error / test 212/212 / build EXIT=0 / self_check 87/87）。
- commit `bbab1c3` feat(record_sheet): 小青账键盘 +/- 运算符生效，外框圆角与按键矮宽。

## 2026-09-14 10:08 金额栏下方显示运算表达式

用户要求：检查删除 / 再记 / 保存键是否仍有「符号占位无功能」问题；金额栏下方显示如 `12 - 3` 的运算表达式。

**修法**（`record_sheet.dart` / `account_form_page.dart`）：
1. 复核三键：删除、再记、保存均有真实功能且已按图文精简要求渲染（删除仅图标、再记/保存仅文字），无需改动。
2. 新增 `_buildExpression()`：
   - 仅在有 pending 运算且当前已输入第二操作数时渲染，显示 `$_pendingAmount $_pendingOperator $_amount`。
   - 右对齐、次级灰字、插入金额栏与备注栏之间。
3. 顺手移除 `account_form_page.dart` 未引用的 `_isSimple` getter，使 `flutter analyze` 0 warning。

**验证**：`flutter analyze --no-fatal-infos` 0 error/0 warning（57 info），`flutter test` 212/212，
`flutter build bundle --debug -v` EXIT=0，`self_check` 87/87。
- commit `15b0821` feat(record_sheet): 金额栏下方显示运算表达式；清理未使用的 _isSimple Getter。

## 2026-09-14 10:26 运算表达式改为独立卡片并常驻显示

用户截图反馈：计算栏要靠右、常驻、单独卡片。

**修法**（`lib/features/record/presentation/record_sheet.dart`）：
- `_buildExpression()` 由纯文本改为独立卡片：与金额栏/备注栏同高（48）、同 surfaceLight 背景、同圆角、同边框。
- 文本 `alignment: Alignment.centerRight` 右对齐。
- 只要 pending 运算存在即渲染；第二操作数为空时显示 `12 -`，运算结束/无 pending 时自动隐藏。

**验证**：四道关卡全绿（analyze / test 212/212 / build EXIT=0 / self_check 87/87）。
- commit `43f0a86` feat(record_sheet): 运算表达式改为独立卡片并常驻显示。

## 2026-09-14 10:37 运算表达式嵌入金额栏并支持删除运算符

用户截图反馈：计算栏高度为金额栏 1/3，表达式显示在金额下方；计算时删除键可删除运算符。

**修法**（`lib/features/record/presentation/record_sheet.dart`）：
- 表达式不再使用独立卡片，而是嵌入金额栏内：有 pending 运算时金额栏拆分为 2:1，表达式占底部 1/3 并左对齐。
- 折叠图标改小，避免在压缩后的金额栏内溢出。
- `_RecordKeypad` 新增 `onBackspace` 回调；当前输入为空时触发，`_onBackspace()` 删除运算符并把第一操作数恢复到当前输入。

**验证**：四道关卡全绿（analyze / test 212/212 / build EXIT=0 / self_check 87/87）。
- commit `b1f0d77` feat(record_sheet): 运算表达式嵌入金额栏内 1/3 区域；删除键可删运算符。

## 2026-09-14 10:55 运算表达式改为左对齐

用户截图反馈表达式右对齐不合适，要求左对齐。

**修法**（`lib/features/record/presentation/record_sheet.dart`）：
- 表达式区域 `Alignment.centerRight` → `Alignment.centerLeft`。
- `_buildExpression()` 中 `textAlign: TextAlign.right` → `TextAlign.left`。

**验证**：四道关卡全绿（analyze / test 212/212 / build EXIT=0 / self_check 87/87）。
- commit `1995fb4` feat(record_sheet): 运算表达式改为左对齐。

## 2026-09-14 11:18 支出功能栏补 8 个按钮

用户要求支出功能栏含：账户、报销、优惠、图片、标签、不计收支、不计预算、模板。检查后确认原已有 7 个（账户、报销[仅expense]、优惠、图片、标签、不计入、模板），缺「不计预算」且「不计入」为合并项。

**修法**（`lib/features/record/presentation/record_sheet.dart`）：
- 新增状态变量 `_excludeFromBudget`。
- 把「不计入」拆成「不计收支」(`_excludeFromStats`) 与「不计预算」(`_excludeFromBudget`) 两个独立开关；「不计预算」图标用 `Icons.pie_chart_outline`。

**验证**：四道关卡全绿（analyze / test 212/212 / build EXIT=0 / self_check 87/87）。
- commit `df03151` feat(record_sheet): 支出功能栏拆分「不计入」为「不计收支」+「不计预算」。

## 2026-09-14 11:29 小青账统一布局同步到收入/转账/借还

用户要求把「功能栏 + 金额栏 + 日期栏 + 键盘」整体同步到收入、转账、借还三个分支。

**修法**（`record_sheet.dart` / `record_tab.dart`）：
- `RecordTab` 新增 `usesNewLayout` getter，覆盖 expense / income / transfer / lend。
- 重构 `_buildCategoryAccountBody()` 为 `_buildNewLayoutBody()` + `_buildNewLayoutScrollArea()`：
  - 统一骨架：顶部滚动表单 + 底部固定「功能栏 / 金额栏 / 日期备注栏 / 小青账键盘」。
  - 滚动区按 Tab 渲染：expense/income 显示分类网格；transfer 显示转出/转入账户；lend 显示对方 + 账户。
- 主体构建改用 `_tab.usesNewLayout`；报销 / 退款 / 存钱仍保持 `_buildLegacyBody()`。

**验证**：四道关卡全绿（analyze / test 212/212 / build EXIT=0 / self_check 87/87）。
- commit `5f73141` feat(record_sheet): 小青账统一布局同步到收入/转账/借还。

## 2026-09-14 11:46 功能栏按钮按 Tab 过滤

用户要求不同 Tab 显示不同功能按钮：
- 收入：账户、图片、标签、不计收支、不计预算、模版
- 转账：图片、标签、模版
- 借还：图片、标签、模版

**修法**（`record_sheet.dart` `_buildFunctionBar`）：
- 新增 `isIncome`；`showAccountStats = isExpense || isIncome`。
- 账户 / 不计收支 / 不计预算：`if (showAccountStats)`（支出、收入显示）。
- 报销 / 优惠：`if (isExpense)`（仅支出显示）。
- 图片 / 标签 / 模板：常显（所有新布局 Tab）。

最终各 Tab 功能栏：
- 支出（8）：账户、报销、优惠、图片、标签、不计收支、不计预算、模板
- 收入（6）：账户、图片、标签、不计收支、不计预算、模板
- 转账（3）：图片、标签、模板
- 借还（3）：图片、标签、模板

**验证**：四道关卡全绿（analyze / test 212/212 / build EXIT=0 / self_check 87/87）。
- commit `b434eaf` feat(record_sheet): 功能栏按钮按 Tab 过滤（收入/转账/借还）。

## 2026-09-14 12:08 转账 Tab 按小青账模板重构

用户截图要求转账页按模板调整：卡片式账户选择器、中间「转至」指示器、手续费/优惠/计算器、说明文案。

**修法**（`record_sheet.dart`）：
- 新增状态 `_feeAmount`。
- 新增 `_buildTransferAccountCard()`：圆角卡片（图标+标签居左、账户名/占位提示居右、右侧箭头），点击弹出底部账户选择器。
- 新增 `_buildTransferFeeRow()` / `_buildTransferTag()` / `_onFee()`：「手续费」「优惠」绿色标签输入，「计算器」按钮。
- 新增 `_buildTransferHint()`：说明文案。
- 重写转账分支的滚动区，按模板排列组件。

**验证**：四道关卡全绿（analyze / test 212/212 / build EXIT=0 / self_check 87/87）。
- commit `031efdc` feat(record_sheet): 转账 Tab 按小青账模板重构账户卡片、手续费/优惠/计算器、说明文案。

## 2026-09-14 12:56 转账账户卡片 7/3 横向排布 + 转至互换

用户截图反馈：两个账户卡片应在一行里按 7/3 分布；「转至」按钮点击后应互换转出/转入账户。

**修法**（`record_sheet.dart`）：
- 新增 `_swapTransferAccounts()`：交换 `_accountId` 与 `_toAccountId`。
- 转账滚动区改为 `Row`：左侧 `Expanded(flex: 7)` 转出账户卡片，中间可点击的「转至」按钮，右侧 `Expanded(flex: 3)` 转入账户卡片。
- 账户卡片文字增加 `maxLines: 1` / `overflow: TextOverflow.ellipsis`，防止窄卡片溢出。

**验证**：四道关卡全绿（analyze / test 212/212 / build EXIT=0 / self_check 87/87）。
- commit `68a87c1` feat(record_sheet): 转账账户卡片改为 7/3 横向排布；转至按钮支持互换账户。

## 2026-09-14 13:08 转账账户卡片改回上下布局

用户截图纠正：转账页应为上下布局——上方转出账户、中间「转至」按钮、下方转入账户，而非左右 7/3 排布。

**修法**（`record_sheet.dart`）：
- 转账滚动区 `_buildNewLayoutScrollArea` 的 `RecordTab.transfer` 改回 `Column`：
  1. 转出账户卡片；
  2. 居中的「转至」按钮（带互换图标）；
  3. 转入账户卡片。
- 保留 `_swapTransferAccounts()`，点击「转至」继续交换转出/转入账户。

**验证**：四道关卡全绿（analyze / test 212/212 / build EXIT=0 / self_check 87/87）。
- commit `eb638ca` feat(record_sheet): 转账账户卡片改回上下布局；保留转至互换。

## 2026-09-14 13:18 转账账户卡片左右分栏：标签 + 账户栏

用户截图要求：转账卡片左侧显示「转出账户/转入账户」标签，右侧显示账户选择栏（已选账户名或占位符 + >）。

**修法**（`record_sheet.dart`）：
- `_buildTransferAccountCard` 移除左侧图标，改为 `Row` 左右 3:7 分栏：
  - 左侧 `Expanded(flex: 3)` 显示标签（如「转出账户」）。
  - 右侧 `Expanded(flex: 7)` 显示账户名/占位符 + `chevron_right` 箭头，居右对齐。
- 调用处（转出 / 转入）同步移除 `icon` 参数。

**验证**：四道关卡全绿（analyze / test 212/212 / build EXIT=0 / self_check 87/87）。
- commit `e0ca8ea` feat(record_sheet): 转账账户卡片左侧显示标签、右侧显示账户栏。

## 2026-09-14 13:31 标签与账户栏拆分为两个独立圆角长条卡片

用户截图要求：标签单独出来在左侧呈现一个圆角长条卡片，右侧的账户栏也是一个圆角长条卡片。

**修法**（`record_sheet.dart`）：
- `_buildTransferAccountCard` 改为 `Row` 包含两个独立圆角长条卡片：
  - 左侧标签卡片：固定高度 48、圆角、背景/边框，居中显示「转出账户/转入账户」。
  - 右侧账户栏卡片：`Expanded` 占满剩余空间，高度/圆角/背景/边框与标签一致，右侧显示账户名/占位符 + `chevron_right`，可点击弹出账户选择器。
- 两卡片之间用 `spaceSm` 间距。

**验证**：四道关卡全绿（analyze / test 212/212 / build EXIT=0 / self_check 87/87）。
- commit `39b0f9c` feat(record_sheet): 转账账户卡片的标签与账户栏拆分为两个独立圆角长条卡片。

## 2026-09-14 13:49 标签卡片移到右侧并移除右箭头

用户截图要求：右箭头移除，把显示「转出账户」或「转入账户」的标签卡片移到右边。

**修法**（`record_sheet.dart`）：
- `_buildTransferAccountCard` 内部两个卡片左右互换：
  - 左侧：`Expanded` 账户栏卡片，显示账户名或占位符，居右对齐，**移除 `chevron_right` 箭头**。
  - 右侧：标签卡片，显示「转出账户/转入账户」。
- 注释同步更新。

**验证**：四道关卡全绿（analyze / test 212/212 / build EXIT=0 / self_check 87/87）。
- commit `ff58482` feat(record_sheet): 转账账户卡片右箭头移除，标签卡片移到右侧。

## 2026-09-14 13:59 账户栏与标签卡片名称互调

用户要求：扣款账户↔转出账户、入款账户↔转入账户 两个名称对调（即左侧账户栏占位符改显示「转出账户/转入账户」，右侧标签卡片改显示「扣款账户/入款账户」）。

**修法**（`record_sheet.dart`）：交换 `_buildTransferAccountCard` 两处调用里的 `label` 与 `placeholder` 取值。

**验证**：四道关卡全绿（analyze / test 212/212 / build EXIT=0 / self_check 87/87）。
- commit `4d86cab` feat(record_sheet): 转账账户栏与标签卡片名称互调。

## 2026-09-14 14:08 账户栏左对齐；手续费/优惠并入同一卡片

用户截图要求：
1. 转出/转入账户栏文字左对齐（原先是右对齐）。
2. 手续费与优惠并入一个与转账账户栏等高的圆角长条卡片，卡片内左侧是输入栏，右侧是「手续费」「优惠」并排的绿色标签按钮。

**修法**（`record_sheet.dart`）：
- `_buildTransferAccountCard`：账户栏卡片内 Row 的 `mainAxisAlignment` 从 `end` 改为 `start`，Text 的 `textAlign` 从 `right` 改为 `left`。
- `_buildTransferFeeRow`：改为一个高度 48 的圆角卡片，内部左侧 `Expanded` 输入栏（占位符「输入金额」或已设置金额摘要），右侧是「手续费」「优惠」两个绿色标签按钮；计算器按钮仍放在卡片右侧外部。
- `_buildTransferTag`：移除 `value` 参数，按钮只显示 `label`，不再直接展示金额。

**验证**：四道关卡全绿（analyze / test 212/212 / build EXIT=0 / self_check 87/87）。
- commit `0cd4542` feat(record_sheet): 转账账户栏左对齐；手续费/优惠并入同一卡片。

## 2026-09-14 14:19 转账手续费/优惠改为左侧输入栏直输、右侧按钮互斥切换

用户截图反馈：手续费和优惠应直接在左侧输入栏输入，右侧「手续费」「优惠」每次只能选一个（互斥）。

**修法**（`record_sheet.dart`）：
- 新增内部枚举 `_FeeInputType { fee, discount }` 与状态 `_feeInputType`。
- 新增 `_feeInputController` / `_feeInputFocusNode`；焦点变化时收起自定义键盘，避免与系统键盘冲突。
- 重写 `_buildTransferFeeRow()`：左侧为 `TextField`（`numberWithOptions(decimal: true)`，占位「输入金额」），`onChanged` 实时写入当前模式变量；右侧「手续费」「优惠」为互斥切换按钮（选中绿底白字，未选浅绿底黑字）。
- 新增 `_onFeeInputTypeChanged()`：切换模式时保存当前输入到旧变量、从新变量恢复输入框内容并请求焦点。
- 移除转账页原弹窗输入入口；支出页功能栏「优惠」仍保留原弹窗。

**验证**：四道关卡全绿（analyze 0 error/0 warning / test 212/212 / build EXIT=0 / self_check 87/87）。
- commit `9e530d2` feat(record_sheet): 转账手续费/优惠改为左侧输入栏直输，右侧按钮互斥切换。

## 2026-09-14 14:45 转账输入框与卡片等高；手续费/优惠参与扣款账户金额计算

用户截图反馈：① 输入框高度要对齐 48dp 卡片；② 手续费在扣款账户金额额外加一笔、优惠额外减一笔。

**修法**：
- `record_sheet.dart`：`_buildTransferFeeRow` 内部 Row 改 `CrossAxisAlignment.stretch`，`TextField` 移除 `isDense`、加 `textAlignVertical.center` 撑满卡片高度；新增 `_feeMinor` / `_discountMinor` getter（字符串→分）；`_save` 转账分支把二者传给 repository；连续记账清空残留。
- `transaction_repository.dart`：`transfer()` 接收 `feeMinor` / `discountMinor`，计算 `fromAmountMinor = amountMinor + feeMinor - discountMinor`；`_applyBalanceDelta` 转账 case 转出方按 `fromAmountMinor` 扣、转入方按 `amountMinor` 加；备注自动拼接手续费/优惠元信息。
- `transfer_repository_test.dart`：新增测试验证手续费/优惠对余额的影响（转账 ¥1000 + ¥5 − ¥2 → 转出扣 ¥1003、转入到 ¥1000、净资产 −¥3）。

**验证**：四道关卡全绿（analyze 0 error/0 warning / test 213/213 / build EXIT=0 / self_check 87/87）。
- commit `af3034d` feat(record_sheet): 转账输入框与卡片等高；手续费/优惠参与扣款账户金额计算。

## 2026-09-14 15:10 转账优惠持久化到数据库；编辑时正确回滚；输入框 UI 调整

用户反馈：① 现金转出没实际减去优惠 2 元（编辑流水页备注含「优惠：¥2.00」，但编辑后余额未按优惠回滚）；② 手续费/优惠输入框做无边框、两个按键高度减少。

**修法**：
1. **数据库 schema v4**：给 `transactions` 表新增 `fee_minor` / `discount_minor` 两列。
   - `tables.dart` 增加 `feeMinor` / `discountMinor`（默认 0）。
   - `app_database.dart` schemaVersion→4，onUpgrade 用 `_addColumnIfMissing` 幂等加列；`build_runner` 重生成 `app_database.g.dart`。
2. **`transaction_repository.dart`**：`add()` 写入这两列与同步 payload；`transfer()` 透传；`updateTransaction()` 新增 `feeMinor`/`discountMinor` 参数并按实际转出扣款金额回滚/重算；`_revertBalanceDelta()`、`remove()` 都按 `amountMinor + feeMinor - discountMinor` 处理转出方。
3. **`edit_transaction_page.dart`**：编辑回填读取 `txn.feeMinor`/`discountMinor`，保存转账时透传，避免编辑后优惠失效。
4. **`record_codec.dart`**：同步解码补 `feeMinor`/`discountMinor`，满足 self_check。
5. **`record_sheet.dart` UI**：转账手续费/优惠卡片去外层边框（无边框）；「手续费」「优惠」切换按钮固定 28dp 高、去边框、垂直居中。
6. **测试**：所有手动构造 `Transaction` 的测试补 `feeMinor:0, discountMinor:0`；`migration_test.dart` user_version 断言 3→4；`transfer_repository_test.dart` 新增「持久化到表」「编辑保留优惠并正确回滚」两例。

**验证**：四道关卡全绿（analyze 0 error/0 warning / test 215/215 / build EXIT=0 / self_check 87/87）。
- commit `70484c6` fix(record_sheet): 转账优惠持久化到数据库；编辑时正确回滚；手续费输入框无边框、按钮高度减少。

## 2026-09-14 16:15 修复转账账户明细/月汇总未含手续费/优惠的显示 bug

用户截图反馈：现金转账到招商 30 元 + 手续费 2 元，现金账户实际扣款应为 32 元，但账户明细列表与月汇总仍按 30 元显示/统计。

**根因**：余额计算逻辑正确（现金已扣 32），但账户明细的 `AccountTransactionTile` 和月统计的 `computeMonthStats` 对 outgoing transfer 只读 `amountMinor`，没把 `feeMinor`/`discountMinor` 算进转出方实际扣款。

**修法**：
- `AccountTransactionTile` 增加 `accountId` 参数，按方向显示实际金额：
  - 转出方 = `amountMinor + feeMinor - discountMinor`
  - 转入方 = `amountMinor`
- `AccountLedgerPage` 把当前账户 ID 传给 tile。
- `computeMonthStats` 对 outgoing transfer 同样按实际扣款统计。
- 测试新增 4 例覆盖手续费/优惠在不同方向上的显示与统计。

**验证**：四道关卡全绿（analyze 0 error/0 warning / test 219/219 / build EXIT=0 / self_check 87/87）。
- commit `d6c7b7f` fix(accounts): 转账账户明细与月汇总按实际扣款显示（含手续费/优惠）。

## 待完善
- 支出/收入页功能键（优惠 / 图片 / 标签 / 报销 / 不计收支 / 不计预算）仍仅切换 UI 状态，未持久化到流水（`_save` 的 TransactionCompanion 未传这些值）。
  - 注：转账页的「手续费」「优惠」已落地（`fee_minor` / `discount_minor`），不参与上述 UI 占位。
- 「不计预算」尚无数据库列，加列需数据库迁移，暂未做。
- 分类「···」菜单未实现。
- 二级分类「添加」未接入分类管理。
