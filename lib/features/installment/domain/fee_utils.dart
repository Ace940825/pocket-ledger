import 'dart:convert';

import '../../../database/app_database.dart';

/// 解析分期计划的「每期利息数组」。
///
/// - 新数据：直接读 [InstallmentPlan.feeByPeriodMinor]（JSON 数组字符串）。
/// - 旧数据 / 字段缺失：按 [InstallmentPlan.feePerPeriodMinor] 平摊兜底。
///
/// 返回的列表长度恒等于 [InstallmentPlan.totalPeriods]，元素单位均为「分」。
List<int> feeByPeriodOf(InstallmentPlan plan) {
  final String? raw = plan.feeByPeriodMinor;
  if (raw != null) {
    try {
      final List<dynamic> arr = jsonDecode(raw) as List<dynamic>;
      if (arr.length == plan.totalPeriods &&
          arr.every((dynamic e) => e is int)) {
        return arr.cast<int>();
      }
    } catch (_) {
      // 解析失败，落到下面的平摊兜底。
    }
  }
  return List<int>.filled(plan.totalPeriods, plan.feePerPeriodMinor);
}

/// 利息扣除方式，用于决定 UI 文案。
enum FeeDeductionMode {
  /// 按期均摊：每期利息相等（含 0 利息）。
  spread,

  /// 首期全部扣除：仅第 1 期非零。
  first,

  /// 尾期全部扣除：仅最后一期非零。
  last,

  /// 其它不规则分布。
  custom,
}

FeeDeductionMode feeDeductionModeOf(InstallmentPlan plan) {
  final List<int> fees = feeByPeriodOf(plan);
  if (fees.every((int e) => e == 0)) return FeeDeductionMode.spread;
  final int first = fees.first;
  final int last = fees.last;
  if (first > 0 && fees.skip(1).every((int e) => e == 0)) {
    return FeeDeductionMode.first;
  }
  if (last > 0 && fees.take(fees.length - 1).every((int e) => e == 0)) {
    return FeeDeductionMode.last;
  }
  if (fees.every((int e) => e == first)) return FeeDeductionMode.spread;
  return FeeDeductionMode.custom;
}
