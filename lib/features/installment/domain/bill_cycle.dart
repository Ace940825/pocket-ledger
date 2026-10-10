/// 账单周期计算工具。
///
/// 负债账户（信用卡/花呗/借呗等）按 [Accounts.billingDay]（每月 X 日）切分账单。
/// 给定某笔交易的「入账日」，即可判定它归属哪个账单周期，进而算出：
/// - 出账单日（周期闭合日）
/// - 还款匹配窗口（出账单日 → 下一个账单日）
///
/// 全部按 UTC 日边界运算，再与用户本地账单日比较，避免时区漂移导致周期错位。
class BillCycle {
  const BillCycle(this.start, this.statement, this.next);

  /// 周期起点（上一个账单日，含）。
  final DateTime start;

  /// 出账单日（本周期闭合日，含）—— 入账日之后第一个账单日。
  final DateTime statement;

  /// 下一个账单日（不含）—— 还款匹配窗口的终点。
  final DateTime next;
}

/// 根据入账日 [postAt]（任意时区，内部统一按 UTC 日边界）与账单日 [billingDay]
/// （1-31）计算所属账单周期。
///
/// [billingDay] 会被 clamp 到 1-28，规避小月（30 天）与 2 月（28/29 天）的越界；
/// 绝大多数账单日都在 1-28 范围内，超界属极个别异常数据，clamp 是最安全的兜底。
BillCycle billCycleOf(DateTime postAt, int billingDay) {
  final int day = billingDay.clamp(1, 28);
  final DateTime d = DateTime.utc(postAt.year, postAt.month, postAt.day);
  final DateTime thisMonthBilling = DateTime.utc(d.year, d.month, day);

  // 入账日 >= 本月账单日（含当日）→ 出账单日顺延到下月账单日；
  // 否则出账单日就是本月账单日。
  final DateTime statement = d.isBefore(thisMonthBilling)
      ? thisMonthBilling
      : DateTime.utc(d.year, d.month + 1, day);

  final DateTime next = DateTime.utc(statement.year, statement.month + 1, day);
  final DateTime start = DateTime.utc(statement.year, statement.month - 1, day);
  return BillCycle(start, statement, next);
}
