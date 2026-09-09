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

/// 账户类型
enum AccountType {
  cash,
  bankCard,
  creditCard,
  eWallet,
  investment,
  other;

  String get label => switch (this) {
        AccountType.cash => '现金',
        AccountType.bankCard => '储蓄卡',
        AccountType.creditCard => '信用卡',
        AccountType.eWallet => '电子钱包',
        AccountType.investment => '投资账户',
        AccountType.other => '其他',
      };
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
  inventory;

  String get label => switch (this) {
        SourceModule.ledger => '日常记账',
        SourceModule.transfer => '转账',
        SourceModule.lend => '借还',
        SourceModule.reimbursement => '报销',
        SourceModule.savings => '储蓄',
        SourceModule.installment => '分期',
        SourceModule.investment => '投资',
        SourceModule.inventory => '物品',
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
