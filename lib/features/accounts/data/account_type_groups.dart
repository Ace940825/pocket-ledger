import '../../../domain/enums.dart';

/// 五大类展示顺序（与新增账户页 Tab 严格一致：资金 / 负债 / 投资 / 应收 / 应付）。
///
/// 注意与 [AccountCategory] 枚举声明顺序不同（枚举为 capital/investment/
/// receivable/debt/payable）——展示顺序是产品口径，单独在此维护。
const List<AccountCategory> kAccountCategoryOrder = <AccountCategory>[
  AccountCategory.capital,
  AccountCategory.debt,
  AccountCategory.investment,
  AccountCategory.receivable,
  AccountCategory.payable,
];

/// 每个大类下可选的账户类型（**唯一事实来源**：新增账户页 Tab 与编辑账户页
/// 「资产类型」弹层共用，避免两处列表漂移）。
///
/// 历史遗留类型 `AccountType.investment`（与基金 / 股票 / 期货 / 现货重复）
/// 不在任何列表中，UI 不再展示。
List<AccountType> accountTypesForCategory(AccountCategory category) =>
    switch (category) {
      // 资金
      AccountCategory.capital => <AccountType>[
          AccountType.cash,
          AccountType.wechat,
          AccountType.alipay,
          AccountType.bankCard,
          AccountType.providentFund,
          AccountType.medicalInsurance,
          AccountType.transitCard,
          AccountType.giftCard,
          AccountType.other,
        ],
      // 负债
      AccountCategory.debt => <AccountType>[
          AccountType.huabei,
          AccountType.jiebei,
          AccountType.baitiao,
          AccountType.creditCard,
          AccountType.meituanMonthly,
          AccountType.douyinMonthly,
          AccountType.otherDebt,
        ],
      // 投资
      AccountCategory.investment => <AccountType>[
          AccountType.fund,
          AccountType.stock,
          AccountType.futures,
          AccountType.spot,
          AccountType.timeDeposit,
          AccountType.investmentOther,
        ],
      // 应收
      AccountCategory.receivable => <AccountType>[
          AccountType.reimbursement,
          AccountType.lend,
        ],
      // 应付
      AccountCategory.payable => <AccountType>[AccountType.borrow],
    };
