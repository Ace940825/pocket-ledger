import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/domain/enums.dart';
import 'package:pocket_ledger/shared/widgets/line_icons.dart';

/// 流水分类图标的统一解析（手绘线稿优先）。
///
/// 与「分类 iconKey → 线稿」的常规链路不同，储蓄流水
/// （`sourceModule == savings`，统一挂系统分类「存款」）的图标按**存取方向**
/// 走储蓄罐线稿：存入 = 罐腹向下箭头 [LineIconKind.depositIn]、
/// 取出 = 罐腹向上箭头 [LineIconKind.depositOut]。
///
/// 原因：系统分类「存款」由 `CategoryRepository.ensureNamed` 落账时自动重建，
/// 不携带 iconKey，若不做方向判定，流水列表会退回 `Icons.swap_horiz`
/// （转账类型兜底）、详情弹层会退回 [LineIconKind.star]（星星兜底），
/// 与「存款」语义不符。
///
/// 其余流水沿用 [categoryLineKind]：命中手绘线稿返回对应 [LineIconKind]，
/// 未命中返回 null（由调用方决定退回 Material 图标还是星形兜底）。
LineIconKind? txnLineIconKind(Transaction txn, Category? category) {
  if (txn.sourceModule == SourceModule.savings) {
    return isSavingsWithdrawal(txn)
        ? LineIconKind.depositOut
        : LineIconKind.depositIn;
  }
  return categoryLineKind(category?.iconKey);
}

/// 储蓄流水是否为「取出」方向。
///
/// 落账口在 `SavingsGoalDetailPage._recordSavingsTxn` / `_recordWithdrawalTxn`：
/// - 存入：note 恒为 `储蓄存入「计划名」`，relatedId 为 `goalId` 或 `goalId#dayIndex`；
/// - 取出：note 恒为 `储蓄取出「计划名」`，relatedId 为 `goalId#withdraw`。
///
/// 两个信号任一命中即判为取出；其余储蓄流水（含历史数据、note 被用户改写过的
/// 行）一律按存入处理 —— 存入是默认语义，退化后仍是储蓄罐，不会变回箭头/星星。
bool isSavingsWithdrawal(Transaction txn) =>
    (txn.relatedId?.endsWith('#withdraw') ?? false) ||
    (txn.note?.startsWith('储蓄取出') ?? false);
