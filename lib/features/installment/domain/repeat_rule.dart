import 'dart:convert';

/// 分期重复周期单位。
enum RepeatUnit {
  day,
  week,
  month,
  year,
}

/// 分期重复周期规则。
///
/// 旧数据或 `unit == null` 时按 [RepeatUnit.month]、每月、间隔 1 处理。
class InstallmentRepeatRule {
  const InstallmentRepeatRule({
    required this.unit,
    this.interval = 1,
    this.weekDay,
    this.monthDay,
    this.monthDays,
    this.month,
  });

  final RepeatUnit unit;

  /// 间隔数量，必须 >= 1。
  ///
  /// 每天：每 [interval] 天；
  /// 每周：每 [interval] 周；
  /// 每月：每 [interval] 个月；
  /// 每年：每 [interval] 年。
  final int interval;

  /// 每周几执行，取值 1-7（周一到周日）。仅 [unit] 为 [RepeatUnit.week] 时有效。
  final int? weekDay;

  /// 每月几号执行，取值 1-31，`-1` 表示月末。仅 [unit] 为 [RepeatUnit.month] 时有效。
  ///
  /// 旧版单值字段，保留以兼容历史数据与现有测试。新代码优先使用 [monthDays]。
  final int? monthDay;

  /// 每月执行的日期列表，取值 1-31，`-1` 表示月末。仅 [unit] 为 [RepeatUnit.month] 时有效。
  ///
  /// 支持多选，例如 `[5, 15, -1]` 表示每月 5 日、15 日与月末。
  final List<int>? monthDays;

  /// 每年几月执行，取值 1-12。仅 [unit] 为 [RepeatUnit.year] 时有效。
  final int? month;

  /// 默认每月执行。
  static const InstallmentRepeatRule monthly = InstallmentRepeatRule(
    unit: RepeatUnit.month,
    interval: 1,
  );

  /// 返回有效的每月日期列表。
  ///
  /// 优先使用 [monthDays]，若为空则退回到单值 [monthDay]。
  List<int>? get _effectiveMonthDays {
    if (monthDays != null && monthDays!.isNotEmpty) return monthDays;
    if (monthDay != null) return <int>[monthDay!];
    return null;
  }

  /// 序列化为 JSON 字符串。
  String toJsonString() {
    final List<int>? days = _effectiveMonthDays;
    return jsonEncode(<String, Object?>{
      'unit': unit.name,
      'interval': interval,
      if (weekDay != null) 'weekDay': weekDay,
      if (days != null && days.isNotEmpty) 'monthDays': days,
      if (month != null) 'month': month,
    });
  }

  /// 从 JSON 字符串解析。
  static InstallmentRepeatRule? fromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final Map<String, Object?> json = jsonDecode(raw) as Map<String, Object?>;
      final String unitName = (json['unit'] as String?) ?? 'month';
      final RepeatUnit unit = RepeatUnit.values.byName(unitName);
      final int interval = (json['interval'] as int?)?.clamp(1, 120) ?? 1;

      final List<int>? parsedMonthDays = (json['monthDays'] as List<dynamic>?)
          ?.map((dynamic d) => (d as num).toInt())
          .toList();

      return InstallmentRepeatRule(
        unit: unit,
        interval: interval,
        weekDay: json['weekDay'] as int?,
        monthDay: json['monthDay'] as int?,
        monthDays: parsedMonthDays,
        month: json['month'] as int?,
      );
    } on Object {
      return null;
    }
  }

  InstallmentRepeatRule copyWith({
    RepeatUnit? unit,
    int? interval,
    int? weekDay,
    int? monthDay,
    List<int>? monthDays,
    int? month,
  }) =>
      InstallmentRepeatRule(
        unit: unit ?? this.unit,
        interval: interval ?? this.interval,
        weekDay: weekDay ?? this.weekDay,
        monthDay: monthDay ?? this.monthDay,
        monthDays: monthDays ?? this.monthDays,
        month: month ?? this.month,
      );

  /// 返回人类可读的中文描述。
  ///
  /// 例如：「每月 16 日」「每 2 周 周一」「每 3 天」「每年 9 月」。
  String displayLabel({int? fallbackDay}) {
    switch (unit) {
      case RepeatUnit.day:
        return interval == 1 ? '每天' : '每 $interval 天';
      case RepeatUnit.week:
        final String dayLabel = _weekDayLabel(weekDay);
        final String prefix = interval == 1 ? '每周' : '每 $interval 周';
        return '$prefix $dayLabel'.trim();
      case RepeatUnit.month:
        final List<int>? days = _effectiveMonthDays;
        final String prefix = interval == 1 ? '每月' : '每 $interval 月';
        if (days == null || days.isEmpty) {
          final String dayLabel = '${fallbackDay ?? 1} 日';
          return '$prefix $dayLabel'.trim();
        }
        if (days.length == 1) {
          final String dayLabel = days.first == -1 ? '月末' : '${days.first} 日';
          return '$prefix $dayLabel'.trim();
        }
        final String daysLabel =
            days.map((int d) => d == -1 ? '月末' : '${d}日').join('、');
        return '$prefix $daysLabel'.trim();
      case RepeatUnit.year:
        final String monthLabel = month == null ? '' : '$month 月';
        final String prefix = interval == 1 ? '每年' : '每 $interval 年';
        return '$prefix $monthLabel'.trim();
    }
  }

  /// 对 UI 而言合理的默认值：切换单位时保留原日期/时间的对应部分。
  static InstallmentRepeatRule defaultFor(
    RepeatUnit unit, {
    required DateTime firstDue,
  }) {
    switch (unit) {
      case RepeatUnit.day:
        return const InstallmentRepeatRule(unit: RepeatUnit.day, interval: 1);
      case RepeatUnit.week:
        return InstallmentRepeatRule(
          unit: RepeatUnit.week,
          interval: 1,
          weekDay: firstDue.weekday,
        );
      case RepeatUnit.month:
        return InstallmentRepeatRule(
          unit: RepeatUnit.month,
          interval: 1,
          monthDays: <int>[firstDue.day],
        );
      case RepeatUnit.year:
        return InstallmentRepeatRule(
          unit: RepeatUnit.year,
          interval: 1,
          month: firstDue.month,
        );
    }
  }

  static String _weekDayLabel(int? weekday) {
    const List<String> labels = <String>[
      '周一',
      '周二',
      '周三',
      '周四',
      '周五',
      '周六',
      '周日',
    ];
    if (weekday == null || weekday < 1 || weekday > 7) return '';
    return labels[weekday - 1];
  }
}
