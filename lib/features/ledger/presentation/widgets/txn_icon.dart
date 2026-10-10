import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/shared/widgets/line_icons.dart';

/// 系统分类名 → 线稿种类（渲染侧兜底字典，与 `bootstrap.dart` 的
/// `systemIconKeys` 数据侧字典同源）。
///
/// 数据侧迁移只在启动时补写「分类行缺 iconKey」的行；若流水挂的分类行
/// 整行缺失（categoryId 悬空）或行存在但 iconKey 未命中，渲染侧按
/// **分类名 → 备注前缀** 继续兜底，保证任何流水都能拿到钢笔线稿，
/// 不再退回 Material 箭头（swap_horiz / north_east / south_west）。
const Map<String, LineIconKind> systemNameLineKinds = <String, LineIconKind>{
  '借入': LineIconKind.borrowIn,
  '借出': LineIconKind.lendOut,
  '还债': LineIconKind.repayDebt,
  '收债': LineIconKind.collectDebt,
  '债务消减': LineIconKind.debtReduce,
  '坏账计提': LineIconKind.badDebt,
  '报销收入': LineIconKind.reimburseIncome,
  '退款': LineIconKind.refundArrow,
  '取现': LineIconKind.withdrawal,
  '还款': LineIconKind.repay,
  '内部转账': LineIconKind.internalTransfer,
  // 旧「转账」大类遗留分类：语义即内部转账。
  '转账': LineIconKind.internalTransfer,
  '存款': LineIconKind.depositIn,
};

/// 备注前缀兜底扫描顺序（长名在前，避免「债务消减」被短名截胡——
/// 当前字典无前缀冲突，但保持按长度降序写死更稳）。
const List<String> _notePrefixOrder = <String>[
  '债务消减',
  '坏账计提',
  '报销收入',
  '内部转账',
  '借入',
  '借出',
  '还债',
  '收债',
  '取现',
  '还款',
  '退款',
  '存款',
];

/// 流水分类图标的统一解析（手绘线稿优先）。
///
/// 解析优先级：
/// 1. 储蓄流水（`sourceModule == savings`，统一挂系统分类「存款」）按
///    **存取方向** 走储蓄罐线稿：存入 = [LineIconKind.depositIn]、
///    取出 = [LineIconKind.depositOut]（方向是交易级信息，分类只存得下
///    一个默认 iconKey，必须渲染侧判定）；
/// 2. 分类 `iconKey` 命中 [categoryLineKind]；
/// 3. 模块级判定：退款 → 退款票据、报销收入 → 票据 ¥、借还流水按
///    「备注前缀 → 分类名 → 收支方向」；
/// 4. 系统分类名兜底（[systemNameLineKinds]，行缺 iconKey 的老数据）；
/// 5. 备注前缀兜底（分类行整体缺失，如「还债-5」「坏账计提-9」这类
///    落账自动拼接的备注；仅借还/转账流水参与扫描，避免误伤普通备注）。
///
/// 未命中返回 null（由调用方决定最终兜底，通常走 [resolveTxnLineIcon]）。
LineIconKind? txnLineIconKind(Transaction txn, Category? category) {
  // 1) 储蓄：按存取方向走储蓄罐（信号见 [isSavingsWithdrawal]）。
  if (txn.sourceModule == SourceModule.savings) {
    return isSavingsWithdrawal(txn)
        ? LineIconKind.depositOut
        : LineIconKind.depositIn;
  }

  // 2) 分类 iconKey 命中线稿（绝大多数用户分类走这里）。
  final LineIconKind? byKey = categoryLineKind(category?.iconKey);
  if (byKey != null) return byKey;

  // 3) 模块级判定（不依赖分类行）。
  if (txn.sourceModule == SourceModule.refund) {
    return LineIconKind.refundArrow;
  }
  if (txn.type == TxnType.income &&
      txn.sourceModule == SourceModule.reimbursement) {
    return LineIconKind.reimburseIncome;
  }
  if (txn.sourceModule == SourceModule.lend) {
    final LineIconKind? byPrefix = _kindByNotePrefix(txn.note);
    if (byPrefix != null) return byPrefix;
    final LineIconKind? byName = systemNameLineKinds[category?.name];
    if (byName != null) return byName;
    // 方向兜底：借出/还债为支出侧，借入/收债为收入侧。
    return txn.type == TxnType.expense
        ? LineIconKind.lendOut
        : LineIconKind.borrowIn;
  }

  // 4) 系统分类名兜底（行存在但没挂 iconKey）。
  final LineIconKind? byName = systemNameLineKinds[category?.name];
  if (byName != null) return byName;

  // 5) 备注前缀兜底（分类行整体缺失；仅借还/转账参与，防误伤普通备注）。
  if (txn.sourceModule == SourceModule.lend || txn.type == TxnType.transfer) {
    return _kindByNotePrefix(txn.note);
  }

  return null;
}

/// 非空解析：[txnLineIconKind] 未命中时按流水类型给**线稿**兜底，
/// 全站流水行/详情弹层统一用它 —— 任何流水都不会再退回 Material 图标。
LineIconKind resolveTxnLineIcon(Transaction txn, Category? category) {
  return txnLineIconKind(txn, category) ??
      switch (txn.type) {
        // 转账类（含取现/还款/内部转账变体缺分类时）→ 双账户互转线稿。
        TxnType.transfer => LineIconKind.internalTransfer,
        // 收支未知分类 → 星形「其他」（与详情弹层历史兜底一致）。
        TxnType.income => LineIconKind.star,
        TxnType.expense => LineIconKind.star,
      };
}

/// 备注前缀 → 系统线稿（「还债-5」「坏账计提-9」等落账拼接备注）。
LineIconKind? _kindByNotePrefix(String? note) {
  if (note == null || note.isEmpty) return null;
  for (final String prefix in _notePrefixOrder) {
    if (note.startsWith(prefix)) return systemNameLineKinds[prefix];
  }
  return null;
}

/// 储蓄流水是否为「取出」方向。
///
/// 落账口在 `SavingsGoalDetailPage._recordSavingsTxn` / `_recordWithdrawalTxn`：
/// - 存入：note = `计划名` 或 `计划名第N期`（2026-10-10 起），relatedId 为
///   `goalId` 或 `goalId#dayIndex`；历史行可能仍是 `储蓄存入「计划名」`；
/// - 取出：note 恒为 `储蓄取出「计划名」`，relatedId 为 `goalId#withdraw`。
///
/// 两个信号任一命中即判为取出；其余储蓄流水（含历史数据、note 被用户改写过的
/// 行）一律按存入处理 —— 存入是默认语义，退化后仍是储蓄罐，不会变回箭头/星星。
bool isSavingsWithdrawal(Transaction txn) =>
    (txn.relatedId?.endsWith('#withdraw') ?? false) ||
    (txn.note?.startsWith('储蓄取出') ?? false);
