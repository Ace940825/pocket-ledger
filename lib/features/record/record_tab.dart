import 'package:flutter/material.dart';

/// 记一笔面板顶部的 7 个业务 Tab（参考小青账）。
///
/// 这是**纯 UI 层**的枚举，与数据库存储无关——它只是决定面板里显示哪一组表单。
/// 真正的存储语义由 [TxnType] / [SourceModule] 承载，避免在 intEnum 下标存储里
/// 硬塞新值（那会触发 tables.dart 注释警告的迁移灾难）。
enum RecordTab {
  expense,
  income,
  transfer,
  lend,
  reimbursement,
  refund,
  savings;

  String get label => switch (this) {
        RecordTab.expense => '支出',
        RecordTab.income => '收入',
        RecordTab.transfer => '转账',
        RecordTab.lend => '借还',
        RecordTab.reimbursement => '报销',
        RecordTab.refund => '退款',
        RecordTab.savings => '存钱',
      };

  IconData get icon => switch (this) {
        RecordTab.expense => Icons.arrow_downward_rounded,
        RecordTab.income => Icons.arrow_upward_rounded,
        RecordTab.transfer => Icons.swap_horiz_rounded,
        RecordTab.lend => Icons.handshake_outlined,
        RecordTab.reimbursement => Icons.receipt_long_outlined,
        RecordTab.refund => Icons.assignment_return_outlined,
        RecordTab.savings => Icons.savings_outlined,
      };

  /// 是否使用小青账统一布局：顶部滚动表单 + 底部固定功能栏/金额栏/日期备注栏/键盘。
  /// 目前覆盖 支出 / 收入 / 转账 / 借还。
  bool get usesNewLayout =>
      this == RecordTab.expense ||
      this == RecordTab.income ||
      this == RecordTab.transfer ||
      this == RecordTab.lend;

  /// 是否使用标准「分类 + 账户」表单（支出 / 收入）。
  bool get usesCategoryAccount =>
      this == RecordTab.expense || this == RecordTab.income;

  /// 是否走 Transactions 表（支出 / 收入 / 转账 / 退款）。
  bool get usesTransactionTable =>
      this == RecordTab.expense ||
      this == RecordTab.income ||
      this == RecordTab.transfer ||
      this == RecordTab.refund;
}
