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

/// 账户：现金 / 储蓄卡 / 信用卡 / 电子钱包 / 投资账户
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
  TextColumn get accountId => text().nullable()();

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

  /// 每期手续费 / 利息（分）
  IntColumn get feePerPeriodMinor => integer().withDefault(const Constant(0))();
  TextColumn get currency => text().withDefault(const Constant('CNY'))();
  TextColumn get accountId => text().nullable()();
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
  IntColumn get purchasePriceMinor => integer().withDefault(const Constant(0))();
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
