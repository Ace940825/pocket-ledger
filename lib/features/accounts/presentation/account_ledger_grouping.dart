import '../../../database/app_database.dart';
import '../../../database/daos/transfer_dedupe.dart';
import '../../../domain/enums.dart';
import '../../../providers/asset_stats_settings.dart';

/// 资产详情页账单按月/按日分组逻辑。
///
/// 纯粹函数，无 UI 依赖，方便单测。

/// 按月聚合的结果。
class MonthGroup {
  const MonthGroup({required this.month, required this.transactions});

  final DateTime month;
  final List<Transaction> transactions;
}

/// 单月账单的统计结果（分）。口径由 [AssetStatsSettings] 决定。
class MonthStats {
  const MonthStats({
    required this.expenseMinor,
    required this.incomeMinor,
    required this.otherMinor,
    required this.showOther,
  });

  /// 支出 = 普通支出账单（+ 转账转出账单，取决于「支出流水统计」开关）。
  final int expenseMinor;

  /// 收入 = 普通收入账单（+ 转账转入账单，取决于「收入流水统计」开关）。
  final int incomeMinor;

  /// 其他 = **没有**被折进支出 / 收入的转账腿合计。
  ///
  /// - 两个转账开关都关：等于全部转账金额（面板默认状态）；
  /// - 只开「支出流水统计」：只剩**转账转入**那条腿（转出已折进支出）；
  /// - 只开「收入流水统计」：只剩**转账转出**那条腿（转入已折进收入）；
  /// - 两个都打开：恒为 `transferUnknown`（正常数据下是 0，转账已全部折进收支）。
  final int otherMinor;

  /// 是否展示「其他」这一项。
  ///
  /// 两个收支开关都打开时，转账已全部折进支出 / 收入，「其他」不再有独立含义 ——
  /// 按参考设计**整项隐藏**（连 `其他:¥0.00` 都不显示）。
  final bool showOther;

  /// 结余 = **支出 − 收入**。
  ///
  /// ⚠️ 口径按产品要求是「支出在前」，与国内常见的「收入 − 支出」相反：
  /// 当月花得比赚得多时，结余为**正数**。
  /// 用的是**已按开关过滤后**的支出 / 收入，所以它和汇总条上显示的数字自洽。
  int get balanceMinor => expenseMinor - incomeMinor;
}

/// 按 [settings] 口径计算某批流水的月统计。
///
/// 规则（与设置面板的副标题一一对应）：
/// - **支出** = 普通支出账单（`TxnType.expense`）
///   + 转账转出账单（仅当 `expenseWithTransfer`）
///   − 退款（仅当 `noOffset == false`，即「进行抵扣」）
/// - **收入** = 普通收入账单（`TxnType.income` 且来源不是退款）
///   + 转账转入账单（仅当 `incomeWithTransfer`）
///   + 退款（仅当 `noOffset == true`，即「不进行抵扣」）
/// - **其他** = 未被计入支出 / 收入的转账腿
///   （`transferDirectionOf` 判定方向；缺少对手方的旧数据也归这里）
/// - **结余** = 支出 − 收入（见 [MonthStats.balanceMinor]）
///
/// 方向判定需要知道「本账户」，所以必须传 [accountId]。
/// 传入的 [transactions] 必须已经过转账去重（见 `dedupeAccountTransfers`），
/// 否则旧库里成对的转账会让「其他」被重复累加。
MonthStats computeMonthStats(
  List<Transaction> transactions,
  AssetStatsSettings settings, {
  required String accountId,
}) {
  int ordinaryExpense = 0;
  int ordinaryIncome = 0;
  int refund = 0;
  int transferOut = 0;
  int transferIn = 0;
  int transferUnknown = 0;

  for (final Transaction t in transactions) {
    switch (t.type) {
      case TxnType.expense:
        ordinaryExpense += t.amountMinor;
      case TxnType.income:
        if (t.sourceModule == SourceModule.refund) {
          refund += t.amountMinor;
        } else {
          ordinaryIncome += t.amountMinor;
        }
      case TxnType.transfer:
        switch (transferDirectionOf(t, accountId)) {
          case TransferDirection.outgoing:
            transferOut += t.amountMinor;
          case TransferDirection.incoming:
            transferIn += t.amountMinor;
          case null:
            // 缺对手方的转账：方向不可判定，只进「其他」。
            transferUnknown += t.amountMinor;
        }
    }
  }

  // 退款：默认抵扣支出；开启「不进行抵扣」后按普通收入计入收入。
  final int expense = ordinaryExpense +
      (settings.expenseWithTransfer ? transferOut : 0) -
      (settings.noOffset ? 0 : refund);
  final int income = ordinaryIncome +
      (settings.incomeWithTransfer ? transferIn : 0) +
      (settings.noOffset ? refund : 0);

  final bool otherFoldedIntoBoth =
      settings.expenseWithTransfer && settings.incomeWithTransfer;
  final int other = transferUnknown +
      (settings.expenseWithTransfer ? 0 : transferOut) +
      (settings.incomeWithTransfer ? 0 : transferIn);

  return MonthStats(
    expenseMinor: expense,
    incomeMinor: income,
    otherMinor: other,
    showOther: !otherFoldedIntoBoth,
  );
}

/// 按日聚合的结果。
class DayGroup {
  const DayGroup({required this.dateAt, required this.transactions});

  /// 该日 00:00 的 UTC 毫秒时间戳，仅用于日期标签渲染。
  final int dateAt;
  final List<Transaction> transactions;
}

/// 返回月份键，如 `2026-09`。
String monthKey(DateTime month) =>
    '${month.year}-${month.month.toString().padLeft(2, '0')}';

/// 把 [transactions] 按本地时区的年月分组，月份按倒序排列。
List<MonthGroup> groupTransactionsByMonth(List<Transaction> transactions) {
  final Map<String, List<Transaction>> map = <String, List<Transaction>>{};
  for (final Transaction t in transactions) {
    final DateTime local = DateTime.fromMillisecondsSinceEpoch(
      t.occurredAt,
      isUtc: true,
    ).toLocal();
    final String key = monthKey(local);
    map.putIfAbsent(key, () => <Transaction>[]).add(t);
  }

  final List<String> keys = map.keys.toList()
    ..sort((String a, String b) => b.compareTo(a));

  return keys.map((String key) {
    final List<String> parts = key.split('-');
    final int year = int.parse(parts[0]);
    final int month = int.parse(parts[1]);
    return MonthGroup(
      month: DateTime(year, month),
      transactions: map[key]!,
    );
  }).toList(growable: false);
}

/// 把 [transactions] 按本地时区的日期分组，日期按倒序排列。
List<DayGroup> groupTransactionsByDay(List<Transaction> transactions) {
  final Map<String, List<Transaction>> map = <String, List<Transaction>>{};
  for (final Transaction t in transactions) {
    final DateTime local = DateTime.fromMillisecondsSinceEpoch(
      t.occurredAt,
      isUtc: true,
    ).toLocal();
    final String key =
        '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    map.putIfAbsent(key, () => <Transaction>[]).add(t);
  }

  final List<String> keys = map.keys.toList()
    ..sort((String a, String b) => b.compareTo(a));

  return keys.map((String key) {
    final List<String> parts = key.split('-');
    final DateTime date = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    return DayGroup(
      dateAt: date.toUtc().millisecondsSinceEpoch,
      transactions: map[key]!,
    );
  }).toList(growable: false);
}
