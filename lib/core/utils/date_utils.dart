/// 日期计算工具。所有对外时间戳一律是 **UTC 毫秒**。
library;

/// 在 [from] 上增加 [months] 个月，并做月末夹取。
///
/// 为什么不用 `DateTime(y, m + n, d)`：Dart 会把 2 月 31 日自动溢出成 3 月 3 日，
/// 而分期账单的语义是「每月同一天，该月没有这天就落在月末」。
/// 例：1 月 31 日 + 1 月 = 2 月 28/29 日，而不是 3 月 3 日。
DateTime addMonths(DateTime from, int months) {
  final int totalMonth = from.month - 1 + months;
  final int year = from.year + (totalMonth / 12).floor();
  final int month = totalMonth % 12 + 1;
  final int day = from.day <= daysInMonth(year, month)
      ? from.day
      : daysInMonth(year, month);
  return DateTime(year, month, day, from.hour, from.minute);
}

/// 指定年月的天数（含闰年处理）。
int daysInMonth(int year, int month) {
  const List<int> days = <int>[31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  if (month == 2 && isLeapYear(year)) return 29;
  return days[month - 1];
}

bool isLeapYear(int year) =>
    (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

/// 当天 00:00（本地时区）对应的 UTC 毫秒。用于按天分组统计。
int startOfDayMs(DateTime local) =>
    DateTime(local.year, local.month, local.day).toUtc().millisecondsSinceEpoch;

/// 某年某月 1 日 00:00（本地）对应的 UTC 毫秒。
int startOfMonthMs(int year, int month) =>
    DateTime(year, month).toUtc().millisecondsSinceEpoch;

/// 下个月 1 日 00:00（本地）对应的 UTC 毫秒，即本月区间的开半闭右端点。
int endOfMonthMs(int year, int month) => month == 12
    ? DateTime(year + 1).toUtc().millisecondsSinceEpoch
    : DateTime(year, month + 1).toUtc().millisecondsSinceEpoch;

/// 预算周期 [periodIndex] 对应的 [起, 止) UTC 毫秒区间。
///
/// - 月度：periodIndex 1-12
/// - 季度：periodIndex 1-4
/// - 年度：periodIndex 固定 0
({int start, int end}) budgetRange({
  required int year,
  required int periodIndex,
  required bool monthly,
  required bool quarterly,
}) {
  if (monthly) {
    return (
      start: startOfMonthMs(year, periodIndex),
      end: endOfMonthMs(year, periodIndex),
    );
  }
  if (quarterly) {
    final int firstMonth = (periodIndex - 1) * 3 + 1;
    return (
      start: startOfMonthMs(year, firstMonth),
      end: endOfMonthMs(year, firstMonth + 2),
    );
  }
  return (
    start: startOfMonthMs(year, 1),
    end: endOfMonthMs(year, 12),
  );
}

/// 当前时间落在指定周期内的序号：月度返回月份，季度返回 1-4，年度返回 0。
int currentPeriodIndex({required bool monthly, required bool quarterly}) {
  final DateTime now = DateTime.now();
  if (monthly) return now.month;
  if (quarterly) return ((now.month - 1) / 3).floor() + 1;
  return 0;
}
