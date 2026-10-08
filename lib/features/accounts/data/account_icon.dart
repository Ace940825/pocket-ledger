import 'package:flutter/material.dart';

import '../../../domain/enums.dart';

/// 各账户类型对应的图标。
///
/// 账户页、资产详情页等需要渲染账户 icon 的地方统一调用本函数，
/// 避免在多个页面里各自维护一套映射。
///
/// 选图原则：中文语境一眼可辨——储蓄卡=银行、信用卡=标准卡、
/// 支付宝=扫码、医保=保障盾、储值卡=卡面、借出/借入=握手往来
/// （与账户页借出/借入汇总行的 handshake 图标同源）。
IconData accountIcon(AccountType type) => switch (type) {
      // 资金类
      AccountType.cash => Icons.payments_outlined,
      AccountType.bankCard => Icons.account_balance_outlined,
      AccountType.eWallet => Icons.account_balance_wallet_outlined,
      AccountType.other => Icons.savings_outlined,
      AccountType.wechat => Icons.chat_bubble_outline,
      AccountType.alipay => Icons.qr_code_scanner,
      AccountType.providentFund => Icons.home_outlined,
      AccountType.medicalInsurance => Icons.health_and_safety_outlined,
      AccountType.transitCard => Icons.directions_bus_outlined,
      AccountType.giftCard => Icons.card_membership_outlined,

      // 投资类
      AccountType.investment => Icons.trending_up,
      AccountType.fund => Icons.pie_chart_outline,
      AccountType.stock => Icons.show_chart,
      AccountType.futures => Icons.swap_horiz,
      AccountType.spot => Icons.inventory_2_outlined,
      AccountType.timeDeposit => Icons.lock_clock_outlined,

      // 应收类
      AccountType.reimbursement => Icons.receipt_long_outlined,
      AccountType.lend => Icons.handshake_outlined,

      // 负债类
      AccountType.creditCard => Icons.credit_card,
      AccountType.huabei => Icons.shopping_bag_outlined,
      AccountType.jiebei => Icons.money_outlined,
      AccountType.baitiao => Icons.receipt_outlined,
      AccountType.meituanMonthly => Icons.restaurant_outlined,
      AccountType.douyinMonthly => Icons.music_note_outlined,
      AccountType.otherDebt => Icons.money_off,

      // 应付类
      AccountType.borrow => Icons.handshake_outlined,
    };
