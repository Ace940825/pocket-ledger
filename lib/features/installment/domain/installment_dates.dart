import '../../../core/utils/date_utils.dart';
import 'repeat_rule.dart';

/// 根据 [firstDue]（本地时间）和重复规则生成 [totalPeriods] 个还款日（本地时间）。
///
/// 旧数据或规则无效时按每月一次处理（保持与升级前行为一致）。
List<DateTime> computeInstallmentDueDates({
  required DateTime firstDue,
  required InstallmentRepeatRule? rule,
  required int totalPeriods,
}) {
  if (totalPeriods <= 0) return <DateTime>[];

  final InstallmentRepeatRule effective =
      rule ?? InstallmentRepeatRule.monthly;

  switch (effective.unit) {
    case RepeatUnit.day:
      return _daily(firstDue, effective.interval, totalPeriods);
    case RepeatUnit.week:
      return _weekly(
        firstDue,
        effective.interval,
        effective.weekDay,
        totalPeriods,
      );
    case RepeatUnit.month:
      return _monthly(
        firstDue,
        effective.interval,
        effective.monthDay,
        effective.monthDays,
        totalPeriods,
      );
    case RepeatUnit.year:
      return _yearly(
        firstDue,
        effective.interval,
        effective.month,
        totalPeriods,
      );
  }
}

List<DateTime> _daily(DateTime firstDue, int interval, int total) {
  final List<DateTime> result = <DateTime>[];
  DateTime current = firstDue;
  for (int i = 0; i < total; i++) {
    result.add(current);
    current = current.add(Duration(days: interval));
  }
  return result;
}

List<DateTime> _weekly(
  DateTime firstDue,
  int interval,
  int? weekDay,
  int total,
) {
  final List<DateTime> result = <DateTime>[];

  // 目标星期几：1-7。未指定时沿用 firstDue 的 weekday。
  final int targetWeekDay = weekDay ?? firstDue.weekday;

  // 把 firstDue 推到最近的一个目标星期几（如果 firstDue 本身不是，则取下一个）。
  int delta = targetWeekDay - firstDue.weekday;
  if (delta < 0) delta += 7;
  DateTime current = firstDue.add(Duration(days: delta));

  for (int i = 0; i < total; i++) {
    result.add(current);
    current = current.add(Duration(days: 7 * interval));
  }
  return result;
}

List<DateTime> _monthly(
  DateTime firstDue,
  int interval,
  int? monthDay,
  List<int>? monthDays,
  int total,
) {
  final List<DateTime> result = <DateTime>[];

  // 目标日期列表：1-31，-1 表示月末。未指定时沿用 firstDue 的 day。
  final List<int> targetDays = monthDays ??
      (monthDay != null ? <int>[monthDay] : null) ??
      <int>[firstDue.day];

  for (int i = 0; i < total; i++) {
    final int day = targetDays[i % targetDays.length];
    final int group = i ~/ targetDays.length;
    final DateTime base = addMonths(firstDue, group * interval);
    final DateTime current = _clampToDay(base, day);
    result.add(current);
  }
  return result;
}

List<DateTime> _yearly(
  DateTime firstDue,
  int interval,
  int? month,
  int total,
) {
  final List<DateTime> result = <DateTime>[];

  // 目标月份：1-12。未指定时沿用 firstDue 的 month。
  final int targetMonth = month ?? firstDue.month;

  // 先调整到目标月份（保持 day，月末夹取）。
  DateTime current = _clampToMonth(firstDue, targetMonth);

  for (int i = 0; i < total; i++) {
    result.add(current);
    current = DateTime(
      current.year + interval,
      current.month,
      current.day,
      current.hour,
      current.minute,
      current.second,
      current.millisecond,
      current.microsecond,
    );
    current = _clampToMonth(current, targetMonth);
  }
  return result;
}

/// 把 [date] 的日期部分换成 [day]，月末夹取。
/// [day] 为 -1 时取当月最后一天。
DateTime _clampToDay(DateTime date, int day) {
  if (day == -1) {
    final int lastDay = daysInMonth(date.year, date.month);
    return DateTime(
      date.year,
      date.month,
      lastDay,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
  }
  final int maxDay = daysInMonth(date.year, date.month);
  return DateTime(
    date.year,
    date.month,
    day <= maxDay ? day : maxDay,
    date.hour,
    date.minute,
    date.second,
    date.millisecond,
    date.microsecond,
  );
}

/// 把 [date] 的月份换成 [month]，保持 day 并月末夹取。
DateTime _clampToMonth(DateTime date, int month) {
  final int clampedMonth = month.clamp(1, 12);
  final int maxDay = daysInMonth(date.year, clampedMonth);
  return DateTime(
    date.year,
    clampedMonth,
    date.day <= maxDay ? date.day : maxDay,
    date.hour,
    date.minute,
    date.second,
    date.millisecond,
    date.microsecond,
  );
}
