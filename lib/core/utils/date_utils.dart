/// 日期计算工具。所有对外时间戳一律是 **UTC 毫秒**。
library;

import 'package:intl/intl.dart';

/// 当前本地时间（中国用户视角的「现在」）。
///
/// 设备/WebView 时区上报为 UTC（offset == 0）时，`DateTime.now()` 会给出
/// 比北京时间早 8 小时的墙钟（如 12:52 vs 20:52）。此处统一兜底 +8，
/// 所有「默认记账时间 / 今天边界」一律用本函数，避免页面间时间不同步。
DateTime localNow() {
  final DateTime now = DateTime.now();
  if (now.timeZoneOffset == Duration.zero) {
    return now.add(const Duration(hours: 8));
  }
  return now;
}

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

/// 返回「9月10日 昨天 星期四」风格的账单日期描述。
///
/// 日期部分按本地时区从时间戳解析，相对描述只保留「今天/昨天/前天」；
/// 三天以上不再显示相对词，只显示「星期 X」。
String accountLedgerDateLabel(int timestamp) {
  final DateTime local = DateTime.fromMillisecondsSinceEpoch(
    timestamp,
    isUtc: true,
  ).toLocal();
  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime date = DateTime(local.year, local.month, local.day);
  final int diff = today.difference(date).inDays;

  const List<String> weekdays = <String>[
    '星期一',
    '星期二',
    '星期三',
    '星期四',
    '星期五',
    '星期六',
    '星期日',
  ];
  final String weekday = weekdays[date.weekday - 1];
  final String relative = switch (diff) {
    0 => '今天',
    1 => '昨天',
    2 => '前天',
    _ => '',
  };

  final String base = DateFormat('M月d日').format(local);
  if (relative.isEmpty) return '$base $weekday';
  return '$base $relative $weekday';
}

/// 账单列表按年月分组用的小标题，如 `2026年9月`。
///
/// 只传 pattern、不传 locale：项目从未调用 `initializeDateFormatting`，
/// 带 locale 会抛 `LocaleDataException`（见 `accountLedgerDateLabel` 的同款处理）。
String ledgerMonthLabel(int timestamp) {
  final DateTime local = DateTime.fromMillisecondsSinceEpoch(
    timestamp,
    isUtc: true,
  ).toLocal();
  return '${local.year}年${local.month}月';
}

/// 两个时间戳是否落在**同一个本地月份**（用于分组标题去重）。
bool sameLocalMonth(int aMs, int bMs) {
  final DateTime a =
      DateTime.fromMillisecondsSinceEpoch(aMs, isUtc: true).toLocal();
  final DateTime b =
      DateTime.fromMillisecondsSinceEpoch(bMs, isUtc: true).toLocal();
  return a.year == b.year && a.month == b.month;
}
