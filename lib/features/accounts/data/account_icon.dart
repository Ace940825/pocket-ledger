import '../../../domain/enums.dart';
import '../../../shared/widgets/line_icons.dart';

/// 各账户类型对应的线稿图标（[LineIconKind]）。
///
/// 账户页、资产详情页、记一笔账户选择等需要渲染账户图标的地方统一调用
/// 本函数，返回线稿种类——与分类图标同套 [LineIcon] 钢笔线稿，整页观感统一。
/// 无匹配时返回 null，由调用方兜底为 [LineIconKind.star]。
///
/// 选图原则：中文语境一眼可辨——储蓄卡=银行立柱、信用卡=信用卡、支付宝/微信
/// =手机应用、医保=医疗十字、公积金=住房、借出/借入=往来箭头（与记一笔资金
/// 往来同源）；三类「其他账户」兜底用 star，语义同「其他」。
LineIconKind? accountLineKind(AccountType type) => switch (type) {
      // 资金类
      AccountType.cash => LineIconKind.moneyBag,
      AccountType.bankCard => LineIconKind.account,
      AccountType.eWallet => LineIconKind.funds,
      AccountType.other => LineIconKind.star,
      AccountType.wechat => LineIconKind.smartphone,
      AccountType.alipay => LineIconKind.smartphone,
      AccountType.providentFund => LineIconKind.house,
      AccountType.medicalInsurance => LineIconKind.medicalCross,
      AccountType.transitCard => LineIconKind.transit,
      AccountType.giftCard => LineIconKind.giftRibbon,
      // 投资类
      AccountType.investment => LineIconKind.trendUp,
      AccountType.fund => LineIconKind.trendUp,
      AccountType.stock => LineIconKind.securities,
      AccountType.futures => LineIconKind.trendUp,
      AccountType.spot => LineIconKind.trendUp,
      AccountType.timeDeposit => LineIconKind.depositIn,
      AccountType.investmentOther => LineIconKind.star,
      // 应收类
      AccountType.reimbursement => LineIconKind.reimbursement,
      AccountType.lend => LineIconKind.lendOut,
      // 负债类
      AccountType.creditCard => LineIconKind.withdrawal,
      AccountType.huabei => LineIconKind.shoppingBag,
      AccountType.jiebei => LineIconKind.lend,
      AccountType.baitiao => LineIconKind.shoppingBag,
      AccountType.meituanMonthly => LineIconKind.food,
      AccountType.douyinMonthly => LineIconKind.musicNote,
      AccountType.otherDebt => LineIconKind.star,
      // 应付类
      AccountType.borrow => LineIconKind.borrowIn,
    };

/// 各**账户分类**（[AccountCategory]）对应的线稿图标（[LineIconKind]）。
///
/// 账户分类头像在多处出现（记一笔账户选择弹层、账本筛选页账户 Tab 等）。
/// 2026-10-15 收敛：此前账户选择弹层内联了一套线稿映射，账本筛选页却仍用
/// Material 图标（wallet_outlined / credit_card / trending_up…），两处观感割裂。
/// 现统一由本函数输出线稿种类，全应用同一分类必得同一图标。
///
/// 选图原则：资金=银行卡面、投资=上升趋势、负债=信用卡面；
/// 应收=钱流入（borrowIn 箭头朝内）、应付=钱流出（repayDebt 箭头朝外），
/// 方向语义与记账「收入/支出」一致。
LineIconKind accountCategoryLineKind(AccountCategory category) =>
    switch (category) {
      AccountCategory.capital => LineIconKind.account,
      AccountCategory.investment => LineIconKind.trendUp,
      AccountCategory.debt => LineIconKind.withdrawal,
      AccountCategory.receivable => LineIconKind.borrowIn,
      AccountCategory.payable => LineIconKind.repayDebt,
    };
