import '../../../database/app_database.dart';
import '../../../domain/enums.dart';

/// 报销页列表按月 / 按年分组与统计的纯函数（无 UI 依赖，方便单测）。
///
/// 口径与小青账资产详情页对齐：
/// - 按月分组仅用于「账单列表按年月分组」开启时的展示（带月份小标题）；
/// - 按年统计用于年份选择弹窗与 Hero「本年已收」汇总；
/// - 「不计入收支」(`excludeFromStats`) 的报销不进入任何汇总金额
///   （与报销页「待收回」汇总口径一致；未指向固定报销账户的待收回只在报销页体现，不进账户列表）。

/// 按月聚合的结果（月份倒序）。
class ReimbMonthGroup {
  const ReimbMonthGroup({required this.month, required this.items});

  final DateTime month;
  final List<Reimbursement> items;
}

/// 单年统计结果（分）。
class ReimbYearStat {
  const ReimbYearStat({
    required this.count,
    required this.pendingMinor,
    required this.reimbursedMinor,
  });

  final int count;
  final int pendingMinor;
  final int reimbursedMinor;

  /// 合计 = 垫付中 + 已收（用于年份弹窗右侧金额）。
  int get totalMinor => pendingMinor + reimbursedMinor;
}

/// 返回月份键，如 `2026-09`。
String reimbMonthKey(DateTime month) =>
    '${month.year}-${month.month.toString().padLeft(2, '0')}';

/// 把 [list] 按本地时区的年月分组，月份按倒序排列。
List<ReimbMonthGroup> groupReimbursementsByMonth(List<Reimbursement> list) {
  final Map<String, List<Reimbursement>> map = <String, List<Reimbursement>>{};
  for (final Reimbursement r in list) {
    final DateTime local =
        DateTime.fromMillisecondsSinceEpoch(r.occurredAt, isUtc: true)
            .toLocal();
    final String key = reimbMonthKey(local);
    (map[key] ??= <Reimbursement>[]).add(r);
  }

  final List<String> keys = map.keys.toList()
    ..sort((String a, String b) => b.compareTo(a));

  return keys.map((String key) {
    final List<String> parts = key.split('-');
    return ReimbMonthGroup(
      month: DateTime(int.parse(parts[0]), int.parse(parts[1])),
      items: map[key]!,
    );
  }).toList(growable: false);
}

/// 按年聚合统计：每年若干笔的「笔数 / 垫付中合计 / 已收合计」。
///
/// 跳过 `excludeFromStats` 的报销，使其不污染汇总金额（与 Hero 口径一致）。
Map<int, ReimbYearStat> computeReimbYearStats(List<Reimbursement> list) {
  final Map<int, ReimbYearStat> map = <int, ReimbYearStat>{};
  for (final Reimbursement r in list) {
    if (r.excludeFromStats) continue;
    final DateTime local =
        DateTime.fromMillisecondsSinceEpoch(r.occurredAt, isUtc: true)
            .toLocal();
    final int year = local.year;
    final ReimbYearStat s = map[year] ??
        const ReimbYearStat(count: 0, pendingMinor: 0, reimbursedMinor: 0);
    final int pending = s.pendingMinor +
        (r.status == ReimbursementStatus.pending ? r.amountMinor : 0);
    map[year] = ReimbYearStat(
      count: s.count + 1,
      pendingMinor: pending,
      reimbursedMinor: s.reimbursedMinor,
    );
  }
  return map;
}

/// 「已收」按年合计（分）：仅统计报销模块落账的收入流水
/// （记一笔报销收入产生的 income，`sourceModule == reimbursement`），
/// 开启「不计收支」的流水同样跳过。
///
/// 与报销记录状态解耦：部分报销实收 20 就计 20，Hero「本年已收」随
/// 收入流水实时同步，不再依赖「已报销」记录的金额。
Map<int, int> computeReceivedByYear(List<Transaction> incomes) {
  final Map<int, int> map = <int, int>{};
  for (final Transaction t in incomes) {
    if (t.sourceModule != SourceModule.reimbursement) continue;
    if (t.excludeFromStats) continue;
    final DateTime local =
        DateTime.fromMillisecondsSinceEpoch(t.occurredAt, isUtc: true)
            .toLocal();
    map[local.year] = (map[local.year] ?? 0) + t.amountMinor;
  }
  return map;
}

/// 全部年份的汇总（笔数 / 垫付中合计 / 已收合计）。
ReimbYearStat allYearsStat(Map<int, ReimbYearStat> byYear) {
  int count = 0;
  int pending = 0;
  int reimbursed = 0;
  for (final ReimbYearStat s in byYear.values) {
    count += s.count;
    pending += s.pendingMinor;
    reimbursed += s.reimbursedMinor;
  }
  return ReimbYearStat(
    count: count,
    pendingMinor: pending,
    reimbursedMinor: reimbursed,
  );
}
