import 'package:flutter/material.dart';

import '../../../domain/enums.dart';

/// 各账户类型对应的图标。
///
/// 账户页、资产详情页等需要渲染账户 icon 的地方统一调用本函数，
/// 避免在多个页面里各自维护一套映射。
IconData accountIcon(AccountType type) => switch (type) {
      // 资金类
      AccountType.cash => Icons.payments_outlined,
      AccountType.bankCard => Icons.credit_card,
      AccountType.eWallet => Icons.account_balance_wallet_outlined,
      AccountType.other => Icons.savings_outlined,
      AccountType.wechat => Icons.chat_bubble_outline,
      AccountType.alipay => Icons.payment_outlined,
      AccountType.providentFund => Icons.home_outlined,
      AccountType.medicalInsurance => Icons.local_hospital_outlined,
      AccountType.transitCard => Icons.directions_bus_outlined,
      AccountType.giftCard => Icons.card_giftcard_outlined,

      // 投资类
      AccountType.investment => Icons.trending_up,
      AccountType.fund => Icons.pie_chart_outline,
      AccountType.stock => Icons.show_chart,
      AccountType.futures => Icons.swap_horiz,
      AccountType.spot => Icons.inventory_2_outlined,

      // 应收类
      AccountType.reimbursement => Icons.receipt_long_outlined,
      AccountType.lend => Icons.arrow_upward,

      // 负债类
      AccountType.creditCard => Icons.credit_score_outlined,
      AccountType.huabei => Icons.shopping_bag_outlined,
      AccountType.jiebei => Icons.money_outlined,
      AccountType.baitiao => Icons.receipt_outlined,
      AccountType.meituanMonthly => Icons.restaurant_outlined,
      AccountType.douyinMonthly => Icons.music_note_outlined,
      AccountType.otherDebt => Icons.account_balance_outlined,

      // 应付类
      AccountType.borrow => Icons.arrow_downward,
    };
