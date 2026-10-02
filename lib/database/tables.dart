import 'package:drift/drift.dart';

import '../domain/enums.dart';

/// 同步元数据字段。
///
/// 每一张需要同步的业务表都必须混入本 mixin。
/// 这 4 个字段是增量同步与冲突解决的全部依据：
/// - [updatedAt] UTC 毫秒。绝不用本地时区，否则多设备时间无法比较。
/// - [deleted]   软删除。物理删除无法同步到云端，必须标记后随同步推送。
/// - [dirty]     本地待同步标记，推送成功后清零。
/// - [syncedAt]  上次成功同步的时间。
mixin SyncColumns on Table {
  IntColumn get updatedAt => integer()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();
  IntColumn get syncedAt => integer().nullable()();
}

/// 账本（支持个人 / 家庭 / 项目多账本，云端共享的最小单位）
class Books extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get currency => text().withDefault(const Constant('CNY'))();
  IntColumn get createdAt => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => <Column>{id};
}

/// 账户：现金、借记卡、信用卡、电子钱包、微信、支付宝、
/// 公积金、医保卡、公交卡、购物卡、基金、股票、期货、现货、
/// 报销、借出、借入、花呗、借呗、白条、美团月付、抖音月付等。
class Accounts extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  TextColumn get name => text()();
  IntColumn get type => intEnum<AccountType>()();

  /// 余额（分）。信用卡为负数表示欠款。
  IntColumn get balanceMinor => integer().withDefault(const Constant(0))();
  TextColumn get currency => text().withDefault(const Constant('CNY'))();

  /// 图标与颜色以字符串 / 整数存储，避免引入二进制资源依赖
  TextColumn get iconKey => text().nullable()();
  IntColumn get colorValue => integer().nullable()();

  /// 信用卡额度（分），仅信用卡账户有意义
  IntColumn get creditLimitMinor => integer().nullable()();

  /// 信用卡账单日 / 还款日（1-31）
  IntColumn get billingDay => integer().nullable()();
  IntColumn get dueDay => integer().nullable()();

  /// 备注
  TextColumn get note => text().nullable()();

  /// 卡号（银行卡 / 信用卡等）
  TextColumn get cardNumber => text().nullable()();

  /// 资产状态：0 使用中 / 1 隐藏 / 2 封存。
  /// 与 [isArchived] 保持同步：非 active 时 isArchived = true。
  IntColumn get status =>
      intEnum<AccountStatus>().withDefault(const Constant(0))();

  /// 是否计入总资产（净值计算）。
  BoolColumn get includeInTotal =>
      boolean().withDefault(const Constant(true))();

  /// 旧版归档标记。保留以兼容旧查询，语义等同于 status != active。
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => <Column>{id};
}

/// 分类：支持两级（parentId 为空表示一级分类）
class Categories extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  TextColumn get name => text()();
  IntColumn get type => intEnum<CategoryType>()();
  TextColumn get parentId => text().nullable()();
  TextColumn get iconKey => text().nullable()();
  IntColumn get colorValue => integer().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  /// 系统分类（借入/借出/转账/报销/退款/分期/存款等落账时由
  /// [CategoryRepository.ensureNamed] 自动重建挂分类）：用户分类管理/图标
  /// 选择器隐藏，仅用于流水挂分类与统计聚合。
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => <Column>{id};
}

/// 流水主表：9 大模块的资金变动统一沉淀于此，
/// 其余模块通过 relatedId 关联，保证财务报表可做全口径聚合。
class Transactions extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  IntColumn get type => intEnum<TxnType>()();

  /// 金额（分），恒为正数，方向由 [type] 决定
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text().withDefault(const Constant('CNY'))();

  /// 支出/收入账户；转账时为转出账户
  TextColumn get accountId => text()();

  /// 转账时的转入账户，其余场景为空
  TextColumn get toAccountId => text().nullable()();

  TextColumn get categoryId => text().nullable()();

  /// 业务发生时间（UTC 毫秒）
  IntColumn get occurredAt => integer()();

  TextColumn get note => text().nullable()();

  /// 票据图片地址，JSON 数组字符串
  TextColumn get attachmentUrls => text().nullable()();

  /// 标签，JSON 数组字符串
  TextColumn get tags => text().nullable()();

  /// 注意：intEnum 列不能用 Constant(int) 作为默认值（类型不匹配），
  /// 因此写入时由 Companions 显式提供枚举值。
  IntColumn get sourceModule => intEnum<SourceModule>()();

  /// 关联的业务记录 ID（如借还记录、分期计划）
  TextColumn get relatedId => text().nullable()();

  /// 同一笔转账的两条流水共享此 ID
  TextColumn get transferGroupId => text().nullable()();

  /// 转账手续费（分）。仅转账有意义，其余场景为 0 / null。
  IntColumn get feeMinor => integer().withDefault(const Constant(0))();

  /// 转账优惠（分）。仅转账有意义，其余场景为 0 / null。
  IntColumn get discountMinor => integer().withDefault(const Constant(0))();

  /// 不计收支：为 true 时该流水不计入收支统计（但账户余额仍照常变动）。
  BoolColumn get excludeFromStats =>
      boolean().withDefault(const Constant(false))();

  /// 不计预算：为 true 时该流水不计入预算已用额度。
  BoolColumn get excludeFromBudget =>
      boolean().withDefault(const Constant(false))();

  /// 报销标记：为 true 表示该笔支出可/已用于报销。
  BoolColumn get isReimbursable =>
      boolean().withDefault(const Constant(false))();

  /// 报销账户：报销支出关联的「报销」类型账户；未选择时为 null。
  TextColumn get reimbursementAccountId => text().nullable()();

  @override
  Set<Column> get primaryKey => <Column>{id};
}

/// 借还记录
class LendRecords extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  IntColumn get direction => intEnum<LendDirection>()();
  IntColumn get status => intEnum<LendStatus>()();
  TextColumn get counterparty => text()();
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text().withDefault(const Constant('CNY'))();

  /// 已还金额（分）
  IntColumn get repaidMinor => integer().withDefault(const Constant(0))();
  IntColumn get occurredAt => integer()();
  IntColumn get dueAt => integer().nullable()();
  TextColumn get note => text().nullable()();

  /// 关联账户：借出时为应收账户 / 借入时为应付（负债）账户。
  TextColumn get accountId => text().nullable()();

  /// 资产账户：借入时实际收到钱的资金账户；借出时实际出钱资金账户。
  TextColumn get toAccountId => text().nullable()();

  /// 利息（分）。借入/借出均可附加利息。
  IntColumn get feeMinor => integer().withDefault(const Constant(0))();

  /// 优惠 / 减免（分）。借入/借出时的减免金额。
  IntColumn get discountMinor => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => <Column>{id};
}

/// 报销记录
class Reimbursements extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  TextColumn get title => text()();
  IntColumn get status => intEnum<ReimbursementStatus>()();
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text().withDefault(const Constant('CNY'))();
  TextColumn get payer => text()();

  /// 报销归属方（公司 / 组织 / 个人）
  TextColumn get target => text().nullable()();
  IntColumn get occurredAt => integer()();
  IntColumn get receivedAt => integer().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get attachmentUrls => text().nullable()();
  TextColumn get transactionId => text().nullable()();

  /// 收款流水：这笔报销被「记一笔报销收入」抵扣时落账的收入流水 ID。
  /// 用于账单明细弹窗反向展示「关联账单」（报销收入 → 垫付账单）。
  TextColumn get incomeTransactionId => text().nullable()();

  /// 抵扣台账：被各笔「报销收入」抵扣的明细，JSON 数组字符串，
  /// 元素 `{"i": 收入流水ID, "a": 抵扣金额(分)}`。同一账单可被多笔收入
  /// 分多次抵扣；删除某笔收入流水时按台账反向恢复（已报销→待报销、
  /// 待收金额加回、垫付余额加回）。
  TextColumn get incomeAllocs => text().nullable()();

  /// 报销账户：产生原始支出的资产账户。
  TextColumn get accountId => text().nullable()();

  /// 收款账户：收到报销款的资产账户。
  TextColumn get toAccountId => text().nullable()();

  /// 是否不计入收支统计。个人垫款、与公司报销无关的可选标记：
  /// 开启后该条不计入报销页「待收回」汇总。
  BoolColumn get excludeFromStats =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => <Column>{id};
}

/// 储蓄目标
class SavingsGoals extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  TextColumn get name => text()();
  IntColumn get targetMinor => integer()();
  IntColumn get currentMinor => integer().withDefault(const Constant(0))();
  TextColumn get currency => text().withDefault(const Constant('CNY'))();
  TextColumn get accountId => text().nullable()();
  IntColumn get deadlineAt => integer().nullable()();
  TextColumn get note => text().nullable()();
  BoolColumn get isAchieved => boolean().withDefault(const Constant(false))();

  /// 是否已归档（停止的计划）。归档目标移入储蓄页「归档」Tab，
  /// 不再出现在「计划」列表，可随时恢复。
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  /// 存钱模式（SavingsMode.name，如 fixed365）。创建时落库；
  /// 历史数据为 null，卡片按「储蓄计划」兜底显示。
  TextColumn get mode => text().nullable()();

  /// 重复周期展示文案（每1天 / 每7天 / 每月1日）。null = 不显示胶囊。
  TextColumn get repeatCycle => text().nullable()();

  /// 结束方式展示文案（如「执行365次结束」「按日期结束」）。null = 不显示。
  TextColumn get endNote => text().nullable()();

  /// 已执行次数：存入 +1、取出 -1（下限 0）。
  IntColumn get depositCount => integer().withDefault(const Constant(0))();

  /// 计划开始日期（本地毫秒，取创建时刻）。逐期存入排期的起点锚点；
  /// 用 updatedAt 会在每次编辑后漂移，故单独落列。历史数据为 null，
  /// 详情页回退用 updatedAt。
  IntColumn get startedAt => integer().nullable()();

  /// 弹性存钱法递增模式：1 = 金额模式（等差），2 = 百分比模式（等比）。
  IntColumn get elasticMode => integer().withDefault(const Constant(1))();

  /// 弹性存钱法首期基础金额 N（分）。排期第 1 期 = N，后续按模式递增。
  IntColumn get elasticBaseMinor => integer().nullable()();

  /// 弹性「金额模式」递增系数（分）：第 i 期 = N + (i - 1) × step。
  IntColumn get elasticStepMinor => integer().nullable()();

  /// 弹性「百分比模式」递增百分比（整数 ×100，如 10% = 1000）。
  IntColumn get elasticPercentHundred => integer().nullable()();

  /// 转出/扣款账户（存钱快捷属性，可空）。
  ///
  /// 计划级默认的「扣款来源」：创建 / 编辑页选中后落库，编辑页与
  /// 「存钱」弹窗把它作为扣款账户的默认值回显（历史数据为 null，
  /// 回退 = 页面态留空由用户选择）。与 [accountId]（入款账户）成对。
  TextColumn get sourceAccountId => text().nullable()();

  @override
  Set<Column> get primaryKey => <Column>{id};
}

/// 储蓄计划逐期存入台账（本地表，不参与云端同步）。
///
/// 每执行一次「第 N 期存入」落一行：按计划排期（见
/// `savings_schedule.dart`）把第 [dayIndex] 期标记为已存入，实际存入
/// 金额 [amountMinor] 可与计划额不同（允许手动改）。删除计划时随之清理。
class SavingsDeposits extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text()();

  /// 所属储蓄计划（SavingsGoals.id）。
  TextColumn get goalId => text()();

  /// 期数（1-based，对应排期第 N 期）。
  IntColumn get dayIndex => integer()();

  /// 实际存入金额（分）。
  IntColumn get amountMinor => integer()();

  /// 实际存入时间（本地毫秒）。
  IntColumn get depositedAt => integer()();

  /// 本次存入备注（可空，存钱弹窗录入）。
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => <Column>{id};
}

/// 分期计划
class InstallmentPlans extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  TextColumn get title => text()();
  IntColumn get totalMinor => integer()();
  IntColumn get totalPeriods => integer()();

  /// 已还期数
  IntColumn get paidPeriods => integer().withDefault(const Constant(0))();

  /// 每期手续费 / 利息（分）——历史_average_值，仅用于兼容旧数据与云端回退。
  ///
  /// 真实的「每期利息明细」以 [feeByPeriodMinor]（JSON 数组）为准；该列为 null
  /// 时，UI 会按本列平摊显示。
  IntColumn get feePerPeriodMinor => integer().withDefault(const Constant(0))();

  /// 每期手续费 / 利息明细（分），JSON 数组字符串，长度等于 [totalPeriods]。
  ///
  /// 用于支持「按期均摊 / 首期全部扣除 / 尾期全部扣除」等利息扣除方式：
  /// 均摊时各元素相等；首期全扣时仅下标 0 非零；尾期全扣时仅末位非零。
  /// 为 null 表示旧数据，按 [feePerPeriodMinor] 平摊处理。
  TextColumn get feeByPeriodMinor => text().nullable()();

  TextColumn get currency => text().withDefault(const Constant('CNY'))();
  TextColumn get accountId => text().nullable()();

  /// 重复周期规则，JSON 字符串。
  ///
  /// 旧数据为 null 时按「每月」处理。结构示例：
  /// `{ "unit": "month", "interval": 1, "monthDays": [15] }`
  TextColumn get repeatRule => text().nullable()();

  IntColumn get firstDueAt => integer()();
  TextColumn get note => text().nullable()();
  BoolColumn get isFinished => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => <Column>{id};
}

/// 分期每期明细
class InstallmentPeriods extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get planId => text()();
  IntColumn get periodIndex => integer()();
  IntColumn get amountMinor => integer()();
  IntColumn get dueAt => integer()();
  IntColumn get paidAt => integer().nullable()();
  TextColumn get transactionId => text().nullable()();

  @override
  Set<Column> get primaryKey => <Column>{id};
}

/// 预算
class Budgets extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  IntColumn get scope => intEnum<BudgetScope>()();
  IntColumn get period => intEnum<BudgetPeriod>()();

  /// 预算额度（分）
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text().withDefault(const Constant('CNY'))();

  /// scope 为 category 时必填
  TextColumn get categoryId => text().nullable()();

  /// 生效年份，如 2026
  IntColumn get year => integer()();

  /// 生效月份或季度序号：月度 1-12，季度 1-4，年度固定 0
  IntColumn get periodIndex => integer().withDefault(const Constant(0))();

  BoolColumn get alertEnabled => boolean().withDefault(const Constant(true))();

  /// 提醒阈值，如 80 表示用掉 80% 时提醒
  IntColumn get alertThreshold => integer().withDefault(const Constant(80))();

  @override
  Set<Column> get primaryKey => <Column>{id};
}

/// 投资持仓
class InvestmentHoldings extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  TextColumn get symbol => text()();
  TextColumn get name => text()();
  IntColumn get type => intEnum<InvestmentType>()();

  /// 份额，放大 1e6 倍存储以保留小数精度
  IntColumn get quantityMicros => integer().withDefault(const Constant(0))();

  /// 成本均价（分）
  IntColumn get avgCostMinor => integer().withDefault(const Constant(0))();

  /// 当前价（分）
  IntColumn get currentPriceMinor => integer().withDefault(const Constant(0))();
  TextColumn get currency => text().withDefault(const Constant('CNY'))();
  TextColumn get accountId => text().nullable()();
  IntColumn get priceUpdatedAt => integer().nullable()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => <Column>{id};
}

/// 物品（资产）管理
class InventoryItems extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  TextColumn get name => text()();
  TextColumn get category => text().nullable()();
  IntColumn get purchasePriceMinor =>
      integer().withDefault(const Constant(0))();
  IntColumn get currentValueMinor => integer().withDefault(const Constant(0))();
  TextColumn get currency => text().withDefault(const Constant('CNY'))();
  IntColumn get purchasedAt => integer()();
  IntColumn get warrantyUntil => integer().nullable()();
  TextColumn get photoUrl => text().nullable()();
  TextColumn get location => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get transactionId => text().nullable()();

  @override
  Set<Column> get primaryKey => <Column>{id};
}

/// 待同步操作队列。
///
/// 为什么不用单个 dirty 标记：一条记录可能在离线期间「先创建再删除」，
/// 单个标记无法表达这个序列，而队列里的两条操作可以按顺序重放。
class PendingOps extends Table {
  IntColumn get localSeq => integer().autoIncrement()();

  /// 目标表名。不能命名为 tableName，会与 Drift 内置的 tableName getter 冲突。
  TextColumn get targetTable => text()();
  TextColumn get recordId => text()();
  IntColumn get opType => intEnum<SyncOpType>()();

  /// 操作内容 JSON；删除操作可为 null
  TextColumn get payload => text().nullable()();
  IntColumn get updatedAt => integer()();
  IntColumn get createdAt => integer()();

  /// 失败重试次数，用于指数退避与错误上报
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
}

/// 记一笔模板（本地，不参与云端同步）。
///
/// 用户把常用的「账户 + 分类 + 备注 + 标签 + 开关 + 金额」存为模板，
/// 下次记一笔时点一下即可一键填充。模板页保存时不写入 Transactions（不产生流水）。
/// 刻意不混入 [SyncColumns]：模板是纯本地偏好，跨设备同步意义不大，
/// 也避免触动同步编解码白名单与 self_check 的「12 张业务表」断言。
class RecordTemplates extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text()();

  /// 模板名称，如「滴滴通勤」。
  TextColumn get name => text()();

  /// 适用 Tab：[RecordTab] 的 index（支出/收入/转账/借还/退款/报销）。
  IntColumn get tabIndex => integer()();

  /// 示例金额（分）。仅用于模板卡展示，套用时仍会带入可改。
  IntColumn get amountMinor => integer().withDefault(const Constant(0))();

  /// 示例优惠（分）。支出/转账模板可带，套用时仍会带入可改。
  IntColumn get discountMinor => integer().withDefault(const Constant(0))();

  /// 默认账户（可选）。
  TextColumn get accountId => text().nullable()();

  /// 转账模板的转入账户（可选）。
  TextColumn get toAccountId => text().nullable()();

  /// 借还模板的对方（可选），如「小米」。
  TextColumn get counterparty => text().nullable()();

  /// 默认分类（可选）。
  TextColumn get categoryId => text().nullable()();

  /// 默认备注（可选）。
  TextColumn get note => text().nullable()();

  /// 标签 JSON 数组（可选）。
  TextColumn get tags => text().nullable()();

  BoolColumn get excludeFromStats =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get excludeFromBudget =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get isReimbursable =>
      boolean().withDefault(const Constant(false))();

  /// 创建时间（UTC 毫秒），用于列表按时间倒序。
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => <Column>{id};
}

/// 标签分组（标签类别）。
///
/// 标签按「分组 → 标签」两级组织，与小青账的「标签」逻辑一致。
/// 作用域决定可见范围：
/// - 通用（[TagScope.general]）：全部账本可用，[bookId] 固定空串；
/// - 账本独立（[TagScope.ledger]）：仅当前账本显示，[bookId] 存实际账本 ID。
///
/// 刻意不进 [SyncTables.all] 与 [RecordCodec.decode]：标签是纯本地偏好，
/// 跨设备同步意义不大，也避免触动同步编解码白名单（同 [RecordTemplates]）。
class TagCategories extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  IntColumn get scope => intEnum<TagScope>()();
  TextColumn get name => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => <Column>{id};
}

/// 标签。
///
/// 挂在某个分组（[categoryId]）下，[scope] 与所属分组一致。
/// 记一笔时流水只存标签**名称**（见 [Transactions.tags] 的 JSON 字符串数组），
/// 因此 [name] 是唯一对外标识，分组仅用于管理归类。
class Tags extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get bookId => text()();
  IntColumn get scope => intEnum<TagScope>()();
  TextColumn get categoryId => text()();
  TextColumn get name => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => <Column>{id};
}
