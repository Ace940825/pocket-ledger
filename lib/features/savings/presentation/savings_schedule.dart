import 'dart:math' show pow;

import '../../../database/app_database.dart';
import 'savings_modes.dart';

/// 逐期存入排期的一项。
class SavingsScheduleEntry {
  const SavingsScheduleEntry({
    required this.index,
    required this.date,
    required this.amountMinor,
    required this.cumulativeMinor,
  });

  /// 期数（1-based）。
  final int index;

  /// 计划存入日期（本地）。
  final DateTime date;

  /// 计划应存金额（分）。
  final int amountMinor;

  /// 截至本期的累计应存金额（分）。
  final int cumulativeMinor;
}

/// 从目标行生成逐期存入排期（详情页期卡网格 + 进度卡结束日期）。
///
/// 各模式口径（总额 = 每期基数 base × 权重，base 由目标 ÷ 权重反推，
/// 故创建页「每期金额 N」→ 目标 = N × 权重，详情页排期与之一致）：
/// - fixed365：365 天递增，第 i 天存 i×base 元（权重 66795 = Σ1..365）；
/// - countdown30：360 期（12 循环 × 30 天），每循环 30,29,…,1 × base 元递减（权重 5580）；
/// - weekday：364 期（52 周 × 每天），每周一~日 base/2base/…/7base 元循环（权重 1456）；
/// - weeks52：52 周递增，第 i 周存 i×base 元（权重 1378 = Σ1..52）；
/// - monthly12：12 期（每月一次），均摊 = 目标 ÷ 12（权重 12）；
/// - fixed / elastic：次数取「结束方式」里的数字（执行N次结束，默认 12），
///   步长按重复周期；弹性各期按递增公式（base = 首期 N）；
///   「不结束」（endNote == null）改为滚动排期：起始日 → 次年年终，
///   定额每期 = 每期金额 N、弹性按递增公式持续（详情页结束显示 —）；
/// - flexible：单期「灵活存入」，应存额 0 = 任意金额（无权重）。
class SavingsSchedule {
  const SavingsSchedule._();

  /// 目标的排期起点：startedAt 为空（历史数据）时回退 updatedAt。
  static DateTime startOf(SavingsGoal goal) {
    final int ms = goal.startedAt ?? goal.updatedAt;
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
  }

  /// 从「执行N次结束」里抽数字；抽数失败回退 [fallback]。
  /// 对外暴露：创建页预算各期合计时复用同一口径。
  static int countFromEndNote(String? endNote, int fallback) {
    if (endNote == null) return fallback;
    final RegExpMatch? m = RegExp(r'(\d+)').firstMatch(endNote);
    if (m == null) return fallback;
    final int? n = int.tryParse(m.group(1)!);
    return (n == null || n <= 0) ? fallback : n;
  }

  /// 不结束计划的滚动排期期数：月步长固定 24 期（约两年）；
  /// 天步长按「起始日 → 次年年终」的天数换算。日历卡 / 期卡据此可浏览。
  static int rollingCount(DateTime start, int stepDays) {
    if (stepDays == 0) return 24;
    final int days =
        DateTime(start.year + 1, 12, 31).difference(start).inDays + 1;
    return (days / stepDays).ceil() + 1;
  }

  /// 各模式「逐期权重和」：总额 = 每期基数 N × 权重。
  /// 均摊模式 = 期数；递增/递减/星期类 = 各期倍率之和（与 [build] 口径一致）。
  /// 创建页据此从「每期金额 N」反推目标总额。
  static int totalWeight(SavingsMode mode, {String? endNote}) {
    switch (mode) {
      case SavingsMode.fixed365:
        return 66795; // 1+2+…+365
      case SavingsMode.countdown30:
        return 5580; // (30+29+…+1) × 12
      case SavingsMode.weekday:
        return 1456; // (1+2+…+7) × 52
      case SavingsMode.weeks52:
        return 1378; // 1+2+…+52
      case SavingsMode.monthly12:
        return 12;
      case SavingsMode.fixed:
      case SavingsMode.elastic:
        return countFromEndNote(endNote, 12);
      case SavingsMode.flexible:
        return 0; // 无固定周期
    }
  }

  /// 重复周期 → 步长（天）；每月按加 1 个月处理（返回 0 表示按月）。
  static int _stepDays(String? repeatCycle) {
    if (repeatCycle == null) return 1;
    if (repeatCycle.contains('月')) return 0;
    final RegExpMatch? m = RegExp(r'(\d+)').firstMatch(repeatCycle);
    final int n = (m == null) ? 1 : (int.tryParse(m.group(1)!) ?? 1);
    return n <= 0 ? 1 : n;
  }

  /// 弹性递增各期金额（分）——创建页预算与详情页排期的**单一事实源**，
  /// 保证「目标合计」与「逐期排期」口径完全一致。
  ///
  /// - 金额模式（[percent]=false）：第 i 期 = [base] + (i-1) × [stepMinor]（等差）；
  /// - 百分比模式（[percent]=true）：第 i 期 = round([base] × (1+r)^(i-1))，
  ///   r = [percentHundred] / 10000（如 2% → 200）。
  static List<int> elasticAmounts({
    required int count,
    required bool percent,
    required int base,
    int? stepMinor,
    int? percentHundred,
  }) {
    final List<int> amounts = <int>[];
    final double r = (percentHundred ?? 0) / 10000.0;
    for (int i = 1; i <= count; i++) {
      final int amount = percent
          ? (base * pow(1 + r, i - 1)).round()
          : base + (i - 1) * (stepMinor ?? 0);
      amounts.add(amount);
    }
    return amounts;
  }

  /// 弹性递增各期合计（分）= 创建页目标金额预览，
  /// 与详情页排期累计（[build] → elastic 分支）一致。
  static int elasticPreviewTotal({
    required int baseMinor,
    required bool percent,
    int? stepMinor,
    int? percentHundred,
    int count = 12,
  }) {
    return elasticAmounts(
      count: count,
      percent: percent,
      base: baseMinor,
      stepMinor: stepMinor,
      percentHundred: percentHundred,
    ).fold(0, (int s, int a) => s + a);
  }

  /// 生成全部排期。flexible 返回单项；其余按模式生成 12~365 项。
  static List<SavingsScheduleEntry> build(SavingsGoal goal) {
    SavingsMode? mode;
    for (final SavingsMode m in SavingsMode.values) {
      if (m.name == goal.mode) mode = m;
    }

    final DateTime start = startOf(goal);
    final List<SavingsScheduleEntry> out = <SavingsScheduleEntry>[];
    int cumulative = 0;

    void addEntry(DateTime date, int amountMinor) {
      cumulative += amountMinor;
      out.add(
        SavingsScheduleEntry(
          index: out.length + 1,
          date: date,
          amountMinor: amountMinor,
          cumulativeMinor: cumulative,
        ),
      );
    }

    DateTime date = start;
    switch (mode) {
      case SavingsMode.fixed365:
        // 第 i 天 = i × base；base = 目标 ÷ 66795（创建页每期金额 N = base）。
        final int base = goal.targetMinor == 0 ? 0 : goal.targetMinor ~/ 66795;
        for (int i = 1; i <= 365; i++) {
          addEntry(start.add(Duration(days: i - 1)), i * base);
        }
      case SavingsMode.countdown30:
        // 每循环 30,29,…,1 × base；base = 目标 ÷ 5580（合计 5580 × base）。
        final int base = goal.targetMinor == 0 ? 0 : goal.targetMinor ~/ 5580;
        for (int i = 1; i <= 360; i++) {
          addEntry(
            start.add(Duration(days: i - 1)),
            (30 - ((i - 1) % 30)) * base,
          );
        }
      case SavingsMode.weekday:
        // 每周循环：周一 base、周二 2base、…、周日 7base（共 52 周 = 364 期）；
        // base = 目标 ÷ 1456（创建页每期金额 N = base），周合计 28base × 52。
        final int base = goal.targetMinor == 0 ? 0 : goal.targetMinor ~/ 1456;
        for (int d = 1; d <= 364; d++) {
          final int weekdayPos = ((d - 1) % 7) + 1; // 1=周一 … 7=周日
          addEntry(start.add(Duration(days: d - 1)), weekdayPos * base);
        }
      case SavingsMode.weeks52:
        // 第 i 周 = i × base；base = 目标 ÷ 1378（创建页每期金额 N = base）。
        final int base = goal.targetMinor == 0 ? 0 : goal.targetMinor ~/ 1378;
        for (int i = 1; i <= 52; i++) {
          addEntry(start.add(Duration(days: 7 * (i - 1))), i * base);
        }
      case SavingsMode.monthly12:
        final int per = goal.targetMinor ~/ 12;
        DateTime d = start;
        for (int i = 1; i <= 12; i++) {
          addEntry(d, per);
          d = DateTime(d.year, d.month + 1, d.day);
        }
      case SavingsMode.fixed:
        final int stepDays = _stepDays(goal.repeatCycle);
        // 不结束（endNote == null）：滚动排期（起始日 → 次年年终），
        // 每期 = 每期金额 N（创建页落库口径 targetMinor = N），无终点。
        if (goal.endNote == null) {
          final int count = rollingCount(start, stepDays);
          for (int i = 1; i <= count; i++) {
            addEntry(date, goal.targetMinor);
            date = stepDays == 0
                ? DateTime(date.year, date.month + 1, date.day)
                : date.add(Duration(days: stepDays));
          }
          break;
        }
        final int count = countFromEndNote(goal.endNote, 12);
        final int per = count == 0 ? 0 : goal.targetMinor ~/ count;
        for (int i = 1; i <= count; i++) {
          addEntry(date, per);
          date = stepDays == 0
              ? DateTime(date.year, date.month + 1, date.day)
              : date.add(Duration(days: stepDays));
        }
      case SavingsMode.elastic:
        final int stepDays = _stepDays(goal.repeatCycle);
        final int base = goal.elasticBaseMinor ?? goal.targetMinor;
        final bool percent = goal.elasticMode == 2;
        // 旧数据（弹性列缺失）或参数不完整：回退均摊，保持兼容不崩。
        final bool fallbackFlat = goal.elasticBaseMinor == null ||
            (percent && goal.elasticPercentHundred == null) ||
            (!percent && goal.elasticStepMinor == null);
        // 不结束（endNote == null）：滚动递增排期（起始日 → 次年年终）；
        // 参数缺失的旧数据回退为每期均摊（targetMinor）。
        if (goal.endNote == null) {
          final int count = rollingCount(start, stepDays);
          final List<int> amounts = fallbackFlat
              ? List<int>.filled(count, goal.targetMinor)
              : elasticAmounts(
                  count: count,
                  percent: percent,
                  base: base,
                  stepMinor: goal.elasticStepMinor,
                  percentHundred: goal.elasticPercentHundred,
                );
          for (int i = 0; i < amounts.length; i++) {
            addEntry(date, amounts[i]);
            date = stepDays == 0
                ? DateTime(date.year, date.month + 1, date.day)
                : date.add(Duration(days: stepDays));
          }
          break;
        }
        final int count = countFromEndNote(goal.endNote, 12);
        if (fallbackFlat) {
          final int per = count == 0 ? 0 : goal.targetMinor ~/ count;
          for (int i = 1; i <= count; i++) {
            addEntry(date, per);
            date = stepDays == 0
                ? DateTime(date.year, date.month + 1, date.day)
                : date.add(Duration(days: stepDays));
          }
          break;
        }
        // 各期递增金额（单一事实源 elasticAmounts），再按周期步进排期。
        final List<int> amounts = elasticAmounts(
          count: count,
          percent: percent,
          base: base,
          stepMinor: goal.elasticStepMinor,
          percentHundred: goal.elasticPercentHundred,
        );
        for (int i = 0; i < amounts.length; i++) {
          addEntry(date, amounts[i]);
          date = stepDays == 0
              ? DateTime(date.year, date.month + 1, date.day)
              : date.add(Duration(days: stepDays));
        }
      case SavingsMode.flexible:
      case null:
        addEntry(start, 0);
    }
    return out;
  }
}
