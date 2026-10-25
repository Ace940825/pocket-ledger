import '../../../database/app_database.dart';
import '../../../database/daos/transfer_dedupe.dart';
import '../../../domain/enums.dart';
import '../../../providers/asset_stats_settings.dart';

/// 资产详情页账单按月/按日分组逻辑。
///
/// 纯粹函数，无 UI 依赖，方便单测。

/// 按月聚合的结果。
class MonthGroup {
  const MonthGroup({
    required this.month,
    required this.transactions,
    this.periodStart,
    this.periodEnd,
  });

  final DateTime month;
  final List<Transaction> transactions;

  /// 账单周期起（含）。仅「按账单周期分组」（见
  /// [groupTransactionsByStatement]）的组有值；自然月分组为 `null`。
  final DateTime? periodStart;

  /// 账单周期止（含）。同上。
  final DateTime? periodEnd;
}

/// 第 [year] 年第 [month] 个月的账单周期起止（本地日期，含两端）。
///
/// [billingDay] 为账单日：本月周期 = （上个月账单日的次日）～（本月账单日，
/// 超出当月天数收敛到月末）。例：账单日 1 号 → 10 月账单周期 =
/// 9月2日～10月1日（与小青账「周期」口径一致）。
///
/// 周期在时间轴上**严格首尾相接**（本期起点 = 上期终点次日），任意一天
/// 恰好属于一个周期。
({DateTime start, DateTime end}) statementPeriod(
  int year,
  int month,
  int billingDay,
) {
  DateTime clampDay(int y, int m, int d) {
    final int lastDay = DateTime(y, m + 1, 0).day;
    return DateTime(y, m, d.clamp(1, lastDay));
  }

  final DateTime end = clampDay(year, month, billingDay);
  final int prevYear = month == 1 ? year - 1 : year;
  final int prevMonth = month == 1 ? 12 : month - 1;
  final DateTime prevEnd = clampDay(prevYear, prevMonth, billingDay);
  // prevEnd 是当月最后一天时 day+1 会自然进位到下月 1 号。
  final DateTime start = DateTime(
    prevEnd.year,
    prevEnd.month,
    prevEnd.day + 1,
  );
  return (start: start, end: end);
}

/// 把 [transactions] 按**账单周期**分组（只保留截止月在 [year] 内的 12 个
/// 周期），按截止月倒序——用于有账单日的负债账户（信用卡/花呗等）资产
/// 详情页，月份行的「支出 / 收入」即该周期的账单合计。
///
/// 传入的流水必须覆盖最早一个周期的起点（1 月周期起点 = 上一年 12 月
/// 账单日次日），见 `accountTransactionsForStatementProvider` 的取数口径；
/// 落在 12 个周期之外的交易（上一年 12 月账单日之前、或本年 12 月账单日
/// 之后属于次年 1 月账单）自然被滤掉。
List<MonthGroup> groupTransactionsByStatement(
  List<Transaction> transactions,
  int billingDay,
  int year,
) {
  final List<({DateTime month, DateTime start, DateTime end})> periods =
      <({DateTime month, DateTime start, DateTime end})>[];
  for (int m = 1; m <= 12; m++) {
    final ({DateTime start, DateTime end}) p =
        statementPeriod(year, m, billingDay);
    periods.add((month: DateTime(year, m), start: p.start, end: p.end));
  }

  final Map<String, List<Transaction>> map = <String, List<Transaction>>{};
  for (final Transaction t in transactions) {
    final DateTime local = DateTime.fromMillisecondsSinceEpoch(
      t.occurredAt,
      isUtc: true,
    ).toLocal();
    final DateTime d = DateTime(local.year, local.month, local.day);
    for (final p in periods) {
      if (!d.isBefore(p.start) && !d.isAfter(p.end)) {
        map.putIfAbsent(monthKey(p.month), () => <Transaction>[]).add(t);
        break;
      }
    }
  }

  final List<String> keys = map.keys.toList()
    ..sort((String a, String b) => b.compareTo(a));

  return keys.map((String key) {
    final ({DateTime month, DateTime start, DateTime end}) p = periods
        .firstWhere(
          (({DateTime month, DateTime start, DateTime end}) e) =>
              monthKey(e.month) == key,
        );
    return MonthGroup(
      month: p.month,
      transactions: map[key]!,
      periodStart: p.start,
      periodEnd: p.end,
    );
  }).toList(growable: false);
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

  /// 其他 = 未被折进支出 / 收入的转账腿 + 借还流水净额。
  ///
  /// - 两个转账开关都关：等于全部转账金额（面板默认状态）；
  /// - 只开「支出流水统计」：只剩**转账转入**那条腿（转出已折进支出）；
  /// - 只开「收入流水统计」：只剩**转账转出**那条腿（转入已折进收入）；
  /// - 两个都打开：恒为 `transferUnknown`（正常数据下是 0，转账已全部折进收支）。
  /// - 借还流水（借出/借入/还债/收债）恒计入：资金流出取正、流入取负，
  ///   与结余「支出 − 收入」的方向语义一致（见 [computeMonthStats]）。
  final int otherMinor;

  /// 是否展示「其他」这一项。
  ///
  /// 两个收支开关都打开时，转账已全部折进支出 / 收入；但借还流水恒计入
  /// 「其他」，所以只要当期有借还流水就仍展示整项。
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
///   + 借还流水净额（借出/还债取正、借入/收债取负）
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
  int lendFlow = 0;

  for (final Transaction t in transactions) {
    // 借还流水（借出/借入/还债/收债）不计收支，但计入「其他」：
    // 资金流出（借出/还债）取正、资金流入（借入/收债）取负。
    if (t.sourceModule == SourceModule.lend) {
      if (t.type == TxnType.expense) {
        lendFlow += t.amountMinor - t.discountMinor;
      } else if (t.type == TxnType.income) {
        lendFlow -= t.amountMinor;
      }
      continue;
    }
    // 「不计收支」的账单仍显示在列表里，但不参与月收支统计
    // （与首页/报表的 watchTotalInRange 口径一致）。
    if (t.excludeFromStats) {
      continue;
    }
    switch (t.type) {
      case TxnType.expense:
        // 实付口径：amount 存优惠前原价，优惠部分不计入支出
        ordinaryExpense += t.amountMinor - t.discountMinor;
      case TxnType.income:
        if (t.sourceModule == SourceModule.refund) {
          refund += t.amountMinor;
        } else {
          ordinaryIncome += t.amountMinor;
        }
      case TxnType.transfer:
        switch (transferDirectionOf(t, accountId)) {
          case TransferDirection.outgoing:
            // 转出方实际扣款要包含手续费 / 优惠。
            transferOut += t.amountMinor + t.feeMinor - t.discountMinor;
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
      lendFlow +
      (settings.expenseWithTransfer ? 0 : transferOut) +
      (settings.incomeWithTransfer ? 0 : transferIn);

  return MonthStats(
    expenseMinor: expense,
    incomeMinor: income,
    otherMinor: other,
    showOther: !otherFoldedIntoBoth || lendFlow != 0,
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
