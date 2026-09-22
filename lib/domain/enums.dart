/// 全应用共享的业务枚举。
///
/// 重要：所有枚举在 Drift 中以 `intEnum<T>()` 存储为**下标整数**。
/// 因此**只能在末尾追加新值，绝不可在中间插入或重排**，否则旧数据会错义。
/// 若必须调整顺序，需同时编写数据库迁移。
library;

/// 流水类型：收入 / 支出 / 转账
enum TxnType {
  income,
  expense,
  transfer;

  /// 是否让账户余额增加。转账不影响总资产，仅内部划转。
  bool get increasesBalance => this == TxnType.income;

  String get label => switch (this) {
        TxnType.income => '收入',
        TxnType.expense => '支出',
        TxnType.transfer => '转账',
      };
}

/// 账户大类：资金 / 投资 / 应收 / 负债 / 应付。
enum AccountCategory {
  capital,
  investment,
  receivable,
  debt,
  payable;

  String get label => switch (this) {
        AccountCategory.capital => '资金',
        AccountCategory.investment => '投资',
        AccountCategory.receivable => '应收',
        AccountCategory.debt => '负债',
        AccountCategory.payable => '应付',
      };
}

/// 账户类型。
///
/// ⚠️ Drift 以 `intEnum()` 存储下标，**只能在末尾追加新值**，不可在中间插入
/// 或重排。本次新增类型全部追加在原有 6 个值之后，旧数据仍可正确解析。
enum AccountType {
  // ---- 原有类型（下标 0-5，顺序不可变） ----
  cash, // 0
  bankCard, // 1
  creditCard, // 2
  eWallet, // 3
  investment, // 4（历史遗留，与「基金/股票/期货/现货」重复，UI 中不再展示）
  other, // 5

  // ---- 资金类（追加） ----
  wechat, // 6
  alipay, // 7
  providentFund, // 8
  medicalInsurance, // 9
  transitCard, // 10
  giftCard, // 11

  // ---- 投资类（追加） ----
  fund, // 12
  stock, // 13
  futures, // 14
  spot, // 15

  // ---- 应收类（追加） ----
  reimbursement, // 16
  lend, // 17

  // ---- 负债类（追加） ----
  huabei, // 18
  jiebei, // 19
  baitiao, // 20
  meituanMonthly, // 21
  douyinMonthly, // 22
  otherDebt, // 23

  // ---- 应付类（追加） ----
  borrow; // 24

  String get label => switch (this) {
        AccountType.cash => '现金',
        AccountType.bankCard => '借记卡',
        AccountType.creditCard => '信用卡',
        AccountType.eWallet => '电子钱包',
        AccountType.investment => '投资账户',
        AccountType.other => '其他账户',
        AccountType.wechat => '微信',
        AccountType.alipay => '支付宝',
        AccountType.providentFund => '公积金',
        AccountType.medicalInsurance => '医保卡',
        AccountType.transitCard => '公交卡',
        AccountType.giftCard => '购物卡',
        AccountType.fund => '基金',
        AccountType.stock => '股票',
        AccountType.futures => '期货',
        AccountType.spot => '现货',
        AccountType.reimbursement => '报销',
        AccountType.lend => '借出',
        AccountType.huabei => '花呗',
        AccountType.jiebei => '借呗',
        AccountType.baitiao => '白条',
        AccountType.meituanMonthly => '美团月付',
        AccountType.douyinMonthly => '抖音月付',
        AccountType.otherDebt => '其他账户',
        AccountType.borrow => '借入',
      };

  /// 所属大类。
  AccountCategory get category => switch (this) {
        AccountType.cash ||
        AccountType.bankCard ||
        AccountType.eWallet ||
        AccountType.other ||
        AccountType.wechat ||
        AccountType.alipay ||
        AccountType.providentFund ||
        AccountType.medicalInsurance ||
        AccountType.transitCard ||
        AccountType.giftCard =>
          AccountCategory.capital,
        AccountType.investment ||
        AccountType.fund ||
        AccountType.stock ||
        AccountType.futures ||
        AccountType.spot =>
          AccountCategory.investment,
        AccountType.reimbursement ||
        AccountType.lend =>
          AccountCategory.receivable,
        AccountType.creditCard ||
        AccountType.huabei ||
        AccountType.jiebei ||
        AccountType.baitiao ||
        AccountType.meituanMonthly ||
        AccountType.douyinMonthly ||
        AccountType.otherDebt =>
          AccountCategory.debt,
        AccountType.borrow => AccountCategory.payable,
      };

  /// 该类型是否属于负债（余额表示欠款）。
  bool get isDebt => category == AccountCategory.debt;
}

/// 资产状态：使用中 / 隐藏 / 封存。
enum AccountStatus {
  active,
  hidden,
  sealed;

  String get label => switch (this) {
        AccountStatus.active => '使用中',
        AccountStatus.hidden => '隐藏',
        AccountStatus.sealed => '封存',
      };

  /// 在净资产/总资产列表中是否可见。
  bool get isVisible => this == AccountStatus.active;

  /// 是否计入总资产。
  bool get includedInTotal => this != AccountStatus.hidden;
}

/// 分类类型
enum CategoryType {
  income,
  expense,
  transfer;

  String get label => switch (this) {
        CategoryType.income => '收入',
        CategoryType.expense => '支出',
        CategoryType.transfer => '转账',
      };
}

/// 借还方向：借出（别人欠我）/ 借入（我欠别人）
enum LendDirection {
  lendOut,
  borrowIn;

  String get label => switch (this) {
        LendDirection.lendOut => '借出',
        LendDirection.borrowIn => '借入',
      };
}

/// 借还状态
enum LendStatus {
  ongoing,
  settled,
  writtenOff;

  String get label => switch (this) {
        LendStatus.ongoing => '进行中',
        LendStatus.settled => '已结清',
        LendStatus.writtenOff => '已核销',
      };
}

/// 报销状态
enum ReimbursementStatus {
  pending,
  submitted,
  reimbursed,
  received;

  String get label => switch (this) {
        ReimbursementStatus.pending => '待报销',
        ReimbursementStatus.submitted => '已提交',
        ReimbursementStatus.reimbursed => '已报销',
        ReimbursementStatus.received => '已收款',
      };
}

/// 预算范围
enum BudgetScope {
  overall,
  category;

  String get label => switch (this) {
        BudgetScope.overall => '总预算',
        BudgetScope.category => '分类预算',
      };
}

/// 预算周期
enum BudgetPeriod {
  monthly,
  quarterly,
  yearly;

  String get label => switch (this) {
        BudgetPeriod.monthly => '月度',
        BudgetPeriod.quarterly => '季度',
        BudgetPeriod.yearly => '年度',
      };
}

/// 投资品种
enum InvestmentType {
  stock,
  fund,
  bond,
  crypto,
  other;

  String get label => switch (this) {
        InvestmentType.stock => '股票',
        InvestmentType.fund => '基金',
        InvestmentType.bond => '债券',
        InvestmentType.crypto => '加密货币',
        InvestmentType.other => '其他',
      };
}

/// 流水来源模块。用于在统一流水表中区分业务归属，
/// 让财务报表既能看全口径，也能按模块下钻。
enum SourceModule {
  ledger,
  transfer,
  lend,
  reimbursement,
  savings,
  installment,
  investment,
  inventory,
  refund; // 末尾追加：退款（钱退回账户）。仅追加，绝不可插入中间，否则旧下标错义。

  String get label => switch (this) {
        SourceModule.ledger => '日常记账',
        SourceModule.transfer => '转账',
        SourceModule.lend => '借还',
        SourceModule.reimbursement => '报销',
        SourceModule.savings => '储蓄',
        SourceModule.installment => '分期',
        SourceModule.investment => '投资',
        SourceModule.inventory => '物品',
        SourceModule.refund => '退款',
      };
}

/// 本地记录的同步状态
enum SyncState {
  synced,
  pending,
  conflict;

  String get label => switch (this) {
        SyncState.synced => '已同步',
        SyncState.pending => '待同步',
        SyncState.conflict => '有冲突',
      };
}

/// 同步操作类型
enum SyncOpType {
  insert,
  update,
  delete;
}

/// 标签作用域。
///
/// ⚠️ Drift 以 `intEnum()` 存储下标，**只能在末尾追加新值**，不可在中间插入
/// 或重排。本次新增类型追加在末尾，旧数据仍可正确解析。
enum TagScope {
  /// 通用：全部账本都可用。
  general,

  /// 账本独立：仅在当前账本内显示。
  ledger;

  String get label => switch (this) {
        TagScope.general => '通用',
        TagScope.ledger => '账本独立',
      };
}
