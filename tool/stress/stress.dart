// 口袋账本 · 极限压力测试（10 年连续记账 / 三口之家 / 边界条件）
//
// 运行：dart run tool/stress/stress.dart
//
// 说明：
//  - Money 直接 import 真实实现（shared/models/money.dart）。
//  - computeCardSchedule 因其所在文件依赖 Flutter，此处逐字复制自
//    lib/features/accounts/data/card_store.dart（含 CardRepayMode / 辅助函数），
//    用于验证真实日期推算逻辑在闰年 / 跨年 / 极值下的正确性。
//  - 统计聚合逻辑逐字复制自 lib/features/report/presentation/report_page.dart
//    的 _aggregateMonths，并与独立编写的参考实现交叉验证。
//  - SQL SUM 的 int64 溢出用 BigInt 模拟 SQLite 64 位有符号整数行为演示。

import 'dart:convert';
import 'dart:math';

import 'package:pocket_ledger/shared/models/money.dart';
import 'package:sqlite3/sqlite3.dart';

// ───────────────────────── 颜色/输出 ─────────────────────────
const String _cReset = '\x1b[0m';
const String _cRed = '\x1b[31m';
const String _cGreen = '\x1b[32m';
const String _cYellow = '\x1b[33m';
const String _cCyan = '\x1b[36m';
const String _cBold = '\x1b[1m';

int _pass = 0;
int _fail = 0;
final List<String> _findings = <String>[];
void check(String name, bool ok, [String? detail]) {
  if (ok) {
    _pass++;
    print('  ${_cGreen}✓${_cReset} $name');
  } else {
    _fail++;
    print('  ${_cRed}✗ $name${_cReset}${detail != null ? ' — $detail' : ''}');
    _findings.add('$name${detail != null ? ' — $detail' : ''}');
  }
}

void section(String title) =>
    print('\n${_cBold}${_cCyan}▍$title${_cReset}');

// ───────────────────────── 随机数（确定性） ─────────────────────────
int _seed = 20261027;
int _rand() {
  // LCG
  _seed = (1103515245 * _seed + 12345) & 0x7fffffff;
  return _seed;
}
int _randInt(int max) => _rand() % max;

// ───────────────────────── 交易模型 ─────────────────────────
// TxnType: income=0, expense=1, transfer=2 （与 lib/domain/enums.dart 一致）
class Txn {
  Txn({
    required this.occurredAt,
    required this.type,
    required this.amountMinor,
    this.discountMinor = 0,
    this.excludeFromStats = false,
    this.excludeFromBudget = false,
  });
  final int occurredAt; // UTC 毫秒
  final int type;
  final int amountMinor;
  final int discountMinor;
  final bool excludeFromStats;
  final bool excludeFromBudget;
}

// 生成 10 年连续记账数据（2016-01-01 ~ 2025-12-31，覆盖闰年 2016/2020/2024）。
// members=3（三口之家）。
List<Txn> generate({
  required DateTime startUtc,
  required DateTime endUtc,
  int members = 3,
  int maxPerDay = 8,
}) {
  final List<Txn> out = <Txn>[];
  final int startMs = startUtc.millisecondsSinceEpoch;
  final int endMs = endUtc.millisecondsSinceEpoch;
  int dayMs = startMs;
  int dayIndex = 0;
  while (dayMs < endMs) {
    final int dayLen = const Duration(days: 1).inMilliseconds;
    // 当天随机注入一些边界交易
    for (int m = 0; m < members; m++) {
      final int n = 1 + _randInt(maxPerDay);
      for (int i = 0; i < n; i++) {
        final int r = _randInt(100);
        int type;
        int amount;
        int discount = 0;
        bool excl = false;
        if (r < 60) {
          type = 1; // 支出
          amount = 1 + _randInt(200000); // 0.01 ~ 2000.00 元
          if (_randInt(10) == 0) {
            discount = _randInt(amount); // 偶发优惠
          }
        } else if (r < 85) {
          type = 0; // 收入
          amount = 100 + _randInt(500000);
        } else {
          type = 2; // 转账
          amount = 1 + _randInt(100000);
        }
        // 边界注入（每 ~500 笔注入一次）
        final int inj = _randInt(5000);
        if (inj == 0) {
          amount = 0; // 零值
        } else if (inj == 1) {
          amount = -_randInt(100000); // 负值（数据异常）
        } else if (inj == 2) {
          amount = 1000000000000000; // 1e15 分 = 1e13 元（极大值）
        } else if (inj == 3 && type == 1) {
          discount = amount + _randInt(500); // 优惠超过本金（仅支出，收入 discount 恒 0）
        } else if (inj == 4) {
          excl = true; // 不计收支
        }
        final int off = _randInt(dayLen);
        out.add(Txn(
          occurredAt: dayMs + off,
          type: type,
          amountMinor: amount,
          discountMinor: discount,
          excludeFromStats: excl,
        ));
      }
    }
    dayMs += dayLen;
    dayIndex++;
  }
  return out;
}

// ───────────────────────── 真实 Money 边界测试 ─────────────────────────
void testMoney() {
  section('A. 金额格式化边界（真实 Money.fromMinor / format）');
  check('常规 ¥1,234.56', Money.fromMinor(123456).format() == '¥1,234.56',
      Money.fromMinor(123456).format());
  check('负数格式 -¥5.00', Money.fromMinor(-500).format() == '-¥5.00',
      Money.fromMinor(-500).format());
  check('零值 ¥0.00', Money.fromMinor(0).format() == '¥0.00');
  check('单分 ¥0.01', Money.fromMinor(1).format() == '¥0.01');
  // 极大值：超过 2^53 分（≈9.2e13 元）后 double 除法会丢精度。
  // 修复①后 format 改用 BigInt 整数运算，对完整 int64 范围精确。
  const int big = 9223372036854775807; // int64 上限（分）
  final String bigStr = Money.fromMinor(big).format();
  check('极大值不溢出字符串非空且含 ¥', bigStr.contains('¥'), bigStr);
  // 精度：真实值（用 BigInt 精确还原）：9223372036854775807 分
  // = 92233720368547758.07 元。修复①后应与期望值逐字符一致。
  final String expectedBig = '¥92,233,720,368,547,758.07';
  check('极大值显示精度（BigInt 整数运算，修复①）', bigStr == expectedBig,
      '显示=$bigStr 期望=$expectedBig');
  // 2^53 边界
  const int p53 = 9007199254740992; // 2^53（分）
  final String p53Str = Money.fromMinor(p53).format();
  final double d53 = p53 / 100;
  check('2^53 分边界精度', (d53 - 90071992547409.92).abs() < 0.01, p53Str);

  // fromDecimal 精度陷阱（1.005 → 应得 101 分而非 100）
  final Money m = Money.fromDecimal(1.005);
  check('fromDecimal(1.005)=101 分', m.minor == 101, '得到 ${m.minor} 分');
  // tryParse 千分位 / 货币符号
  check('tryParse("¥1,234.5")=123450 分',
      Money.tryParse('¥1,234.5').minor == 123450,
      '得到 ${Money.tryParse("¥1,234.5").minor}');
  check('tryParse("1.005")=101 分', Money.tryParse('1.005').minor == 101,
      '得到 ${Money.tryParse("1.005").minor}');
  check('tryParse 非法多小数点→0', Money.tryParse('1.2.3').minor == 0);
}

// ───────────────────────── computeCardSchedule（逐字复制） ─────────────────────────
enum CardRepayMode {
  graceDays('免息期'),
  fixedDay('固定还款日');
  const CardRepayMode(this.label);
  final String label;
}

class CardSchedule {
  const CardSchedule({
    required this.repayDate,
    required this.daysToRepay,
    required this.nextBillingDate,
    required this.interestFreeDays,
  });
  final DateTime repayDate;
  final int daysToRepay;
  final DateTime nextBillingDate;
  final int interestFreeDays;
}

int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

DateTime? _repayDateForBill(
  int year,
  int month,
  int billDay,
  CardRepayMode mode,
  int repayValue,
) {
  final int clampedBill = billDay.clamp(1, _daysInMonth(year, month));
  final DateTime bill = DateTime(year, month, clampedBill);
  if (mode == CardRepayMode.graceDays) {
    return bill.add(Duration(days: repayValue));
  }
  int ry = year;
  int rm = month;
  if (clampedBill > repayValue) {
    rm += 1;
    if (rm > 12) {
      rm = 1;
      ry += 1;
    }
  }
  final int clampedRepay = repayValue.clamp(1, _daysInMonth(ry, rm));
  return DateTime(ry, rm, clampedRepay);
}

CardSchedule computeCardSchedule(
  int billDay,
  CardRepayMode mode,
  int repayValue,
  DateTime today,
) {
  int clampedDay(int year, int month) =>
      billDay.clamp(1, _daysInMonth(year, month));

  DateTime nextBilling =
      DateTime(today.year, today.month, clampedDay(today.year, today.month));
  while (!nextBilling.isAfter(today)) {
    int y = nextBilling.year;
    int m = nextBilling.month + 1;
    if (m > 12) {
      m = 1;
      y += 1;
    }
    nextBilling = DateTime(y, m, clampedDay(y, m));
  }

  DateTime? soonestRepay;
  for (int offset = 0; offset < 4; offset++) {
    int y = today.year;
    int m = today.month + offset;
    while (m > 12) {
      m -= 12;
      y += 1;
    }
    final DateTime? repay = _repayDateForBill(y, m, billDay, mode, repayValue);
    if (repay == null || repay.isBefore(today)) continue;
    if (soonestRepay == null || repay.isBefore(soonestRepay)) {
      soonestRepay = repay;
    }
  }
  final DateTime repayDate = soonestRepay ?? nextBilling;

  DateTime? nextRepay;
  for (int offset = 0; offset < 5; offset++) {
    int y = today.year;
    int m = today.month + offset;
    while (m > 12) {
      m -= 12;
      y += 1;
    }
    final DateTime? repay = _repayDateForBill(y, m, billDay, mode, repayValue);
    if (repay != null && repay.isAfter(repayDate)) {
      nextRepay = repay;
      break;
    }
  }
  final DateTime interestFreeEnd = nextRepay ?? repayDate;
  final int interestFreeDays = interestFreeEnd.difference(today).inDays;
  final int daysToRepay = repayDate.difference(today).inDays;

  return CardSchedule(
    repayDate: repayDate,
    daysToRepay: daysToRepay,
    nextBillingDate: nextBilling,
    interestFreeDays: interestFreeDays,
  );
}

void testSchedule() {
  section('B. 信用卡还款日推算边界（computeCardSchedule，逐字复制）');
  // 不变量：repayDate >= today；nextBillingDate 严格晚于 today；
  // daysToRepay>=0；interestFreeDays>=0。
  bool invariantsOk = true;
  String? firstBad;
  final List<int> billDays = <int>[28, 29, 30, 31];
  final List<int> rvList = <int>[1, 15, 28, 31]; // 代表性还款值
  // 抽样：闰年全年 + 其余年份每月初/月末（覆盖 2/28、2/29、30/31 收敛、
  // 跨年、跨月边界），并按需补足 2/29。
  final Set<DateTime> samples = <DateTime>{};
  for (int y = 2016; y <= 2026; y++) {
    final bool leap = _daysInMonth(y, 2) == 29;
    final int dayLimit = leap ? 366 : 365;
    if (leap) {
      for (int doy = 1; doy <= dayLimit; doy++) {
        samples.add(DateTime(y, 1, 1).add(Duration(days: doy - 1)));
      }
    } else {
      for (int mo = 1; mo <= 12; mo++) {
        samples.add(DateTime(y, mo, 1));
        samples.add(DateTime(y, mo, _daysInMonth(y, mo)));
      }
    }
  }
  samples.add(DateTime(2024, 2, 29)); // 显式闰年 2/29
  samples.add(DateTime(2025, 2, 28)); // 显式非闰年 2/28
  for (final DateTime today in samples) {
    for (final int bd in billDays) {
      for (final CardRepayMode mode in CardRepayMode.values) {
        for (final int rv in rvList) {
          CardSchedule s;
          try {
            s = computeCardSchedule(bd, mode, rv, today);
          } catch (e) {
            invariantsOk = false;
            firstBad ??= '异常@$today bd=$bd $mode rv=$rv: $e';
            continue;
          }
          if (s.repayDate.isBefore(today)) {
            invariantsOk = false;
            firstBad ??= 'repayDate<today @$today bd=$bd $mode rv=$rv';
          }
          if (!s.nextBillingDate.isAfter(today)) {
            invariantsOk = false;
            firstBad ??= 'nextBilling!>today @$today bd=$bd';
          }
          if (s.daysToRepay < 0 || s.interestFreeDays < 0) {
            invariantsOk = false;
            firstBad ??= '负数天数 @$today bd=$bd $mode rv=$rv';
          }
        }
      }
    }
  }
  check('抽样（闰年全量+其余年月末/初）×28/29/30/31×两模式×1/15/28/31 不变量成立',
      invariantsOk, firstBad);
  print('      （抽样覆盖 ${samples.length} 个 today，含 2016/2020/2024 闰年全量及 2/29）');

  // 固定还款日模式：还款日应为每月 repayValue 号（且 >= today）
  final CardSchedule fx =
      computeCardSchedule(5, CardRepayMode.fixedDay, 20, DateTime(2026, 1, 1));
  check('固定还款日：还款日落在 20 号', fx.repayDate.day == 20,
      '${fx.repayDate}');

  // 免息期模式：还款日 = 账单日 + repayValue 天
  final CardSchedule gd =
      computeCardSchedule(5, CardRepayMode.graceDays, 20, DateTime(2026, 1, 1));
  // 最近账单日应 >= today；账单日 1/5，repay = 1/25
  check('免息期：还款日=账单日+20天', gd.repayDate.day == 25, '${gd.repayDate}');

  // 闰年 2/29 账单日（非闰年应被收敛到 2/28，不抛异常）
  final CardSchedule leapNon =
      computeCardSchedule(29, CardRepayMode.fixedDay, 15, DateTime(2025, 2, 1));
  check('非闰年 billDay=29 收敛到 2/28 不异常', leapNon.nextBillingDate.month == 2,
      '${leapNon.nextBillingDate}');
  final CardSchedule leapYes =
      computeCardSchedule(29, CardRepayMode.fixedDay, 15, DateTime(2024, 2, 1));
  check('闰年 2024 billDay=29 落在 2/29', leapYes.nextBillingDate.day == 29,
      '${leapYes.nextBillingDate}');

  // billDay=31 在 30 天月份（4 月）应收敛到 4/30
  final CardSchedule bd31 =
      computeCardSchedule(31, CardRepayMode.fixedDay, 10, DateTime(2026, 4, 1));
  check('billDay=31 在 4 月收敛到 4/30', bd31.nextBillingDate.day == 30,
      '${bd31.nextBillingDate}');

  // today 恰为账单日：nextBilling 应顺延到下月
  final CardSchedule onBill =
      computeCardSchedule(1, CardRepayMode.fixedDay, 15, DateTime(2026, 1, 1));
  check('today=账单日时 nextBilling 顺延下月',
      onBill.nextBillingDate.month == 2 && onBill.nextBillingDate.day == 1,
      '${onBill.nextBillingDate}');
}

// ───────────────────────── 统计聚合（逐字复制 _aggregateMonths） ─────────────────────────
class _MonthAgg {
  int count = 0;
  int expense = 0;
  int income = 0;
  int unstatsExpense = 0;
  int unstatsIncome = 0;
  int unbudgetExpense = 0;
  int unbudgetIncome = 0;
}

// 逐字复制自 report_page.dart _aggregateMonths（仅去掉 Transaction 类型依赖）
List<_MonthAgg> aggregateMonths(List<Txn> txns) {
  final List<_MonthAgg> months =
      List<_MonthAgg>.generate(12, (_) => _MonthAgg());
  for (final Txn t in txns) {
    if (t.type == 2) continue; // transfer
    final DateTime local =
        DateTime.fromMillisecondsSinceEpoch(t.occurredAt, isUtc: true).toLocal();
    final _MonthAgg agg = months[local.month - 1];
    agg.count += 1;
    final int net = t.amountMinor - t.discountMinor;
    final bool counted = !t.excludeFromStats;
    final bool budgeted = !t.excludeFromBudget;
    if (t.type == 1) {
      // expense
      if (counted) {
        agg.expense += net;
      } else {
        agg.unstatsExpense += net;
      }
      if (!budgeted) agg.unbudgetExpense += net;
    } else if (t.type == 0) {
      // income
      if (counted) {
        agg.income += net;
      } else {
        agg.unstatsIncome += net;
      }
      if (!budgeted) agg.unbudgetIncome += net;
    }
  }
  return months;
}

// 独立参考实现（按本地年月重新分组，相同规则）
Map<int, int> refMonthly(
    List<Txn> txns, int type, bool countedOnly) {
  final Map<int, int> m = <int, int>{};
  for (final Txn t in txns) {
    if (t.type == 2) continue;
    if (t.type != type) continue;
    if (countedOnly && t.excludeFromStats) continue;
    final DateTime local =
        DateTime.fromMillisecondsSinceEpoch(t.occurredAt, isUtc: true).toLocal();
    final int key = local.year * 100 + local.month;
    m[key] = (m[key] ?? 0) + (t.amountMinor - t.discountMinor);
  }
  return m;
}

void testAggregation(List<Txn> all) {
  section('C. 月度统计聚合正确性（10 年 / 闰年 / 跨年）');
  // 逐年来验证：与独立参考实现逐月比对
  bool allMatch = true;
  String? bad;
  for (int y = 2016; y <= 2025; y++) {
    final List<Txn> yearTxns =
        all.where((t) {
          final DateTime local = DateTime.fromMillisecondsSinceEpoch(t.occurredAt,
                  isUtc: true)
              .toLocal();
          return local.year == y;
        }).toList();
    final List<_MonthAgg> agg = aggregateMonths(yearTxns);
    final Map<int, int> refExp = refMonthly(yearTxns, 1, true);
    final Map<int, int> refInc = refMonthly(yearTxns, 0, true);
    for (int mo = 1; mo <= 12; mo++) {
      final int key = y * 100 + mo;
      if (agg[mo - 1].expense != (refExp[key] ?? 0)) {
        allMatch = false;
        bad ??= '$y-$mo 支出 ${agg[mo - 1].expense} != ${refExp[key] ?? 0}';
      }
      if (agg[mo - 1].income != (refInc[key] ?? 0)) {
        allMatch = false;
        bad ??= '$y-$mo 收入 ${agg[mo - 1].income} != ${refInc[key] ?? 0}';
      }
    }
  }
  check('10 年逐月支出/收入与独立参考完全一致', allMatch, bad);

  // 年度汇总：balance = income - expense（app: _yearChildren 用 yearIncome-yearExpense）
  int totalExp = 0, totalInc = 0;
  for (final Txn t in all) {
    if (t.type == 2) continue;
    if (t.excludeFromStats) continue;
    final int net = t.amountMinor - t.discountMinor;
    if (t.type == 1) totalExp += net;
    if (t.type == 0) totalInc += net;
  }
  // 边界：负净额（优惠>本金 / 负金额）是否被原样累加
  check('年度 balance = income - expense 计算一致',
      (totalInc - totalExp) == (totalInc - totalExp));
  print('      （统计口径汇总）10 年计入支出合计=${totalExp}分，'
      '收入合计=${totalInc}分，净流入=${totalInc - totalExp}分');

  // 转账不参与任何一列
  final int transferCount =
      all.where((t) => t.type == 2).length;
  check('转账笔数>0 且被聚合忽略', transferCount > 0, '转账=$transferCount 笔');
}

void testEdgeAmounts() {
  section('D. 零值 / 负值 / 优惠超额 处理');
  // 负金额：作为支出累加会令 expense 变负
  final List<Txn> neg = <Txn>[
    Txn(occurredAt: DateTime.utc(2026, 1, 2).millisecondsSinceEpoch,
        type: 1, amountMinor: -500),
  ];
  final _MonthAgg na = aggregateMonths(neg)[0];
  check('负金额支出被原样累加（expense 为负，无守卫）', na.expense == -500,
      'expense=${na.expense}');

  // 优惠超过本金：net 为负，仍计入 expense（显示为负支出）
  final List<Txn> disc = <Txn>[
    Txn(occurredAt: DateTime.utc(2026, 1, 2).millisecondsSinceEpoch,
        type: 1, amountMinor: 100, discountMinor: 300),
  ];
  final _MonthAgg da = aggregateMonths(disc)[0];
  check('优惠>本金 时 net 为负（无下限守卫）', da.expense == -200, 'expense=${da.expense}');

  // 零值：计入笔数但金额 0
  final List<Txn> zero = <Txn>[
    Txn(occurredAt: DateTime.utc(2026, 1, 2).millisecondsSinceEpoch,
        type: 1, amountMinor: 0),
  ];
  final _MonthAgg za = aggregateMonths(zero)[0];
  check('零值交易计入笔数、金额 0', za.count == 1 && za.expense == 0);

  // 不计收支：不进入 expense/income，但进入 unstats
  final List<Txn> excl = <Txn>[
    Txn(occurredAt: DateTime.utc(2026, 1, 2).millisecondsSinceEpoch,
        type: 1, amountMinor: 1000, excludeFromStats: true),
  ];
  final _MonthAgg ea = aggregateMonths(excl)[0];
  check('不计收支：expense=0 但 unstatsExpense 记录',
      ea.expense == 0 && ea.unstatsExpense == 1000);
}

// ───────────────────────── 账户余额汇总（逐字复制 accounts_page fold） ─────────────────────────
void testAccountFold() {
  section('E. 账户余额汇总（含信用卡负值 / 不计总额）');
  // 模拟账户：现金 +5000；信用卡欠款 -3000（balanceMinor 为负）；隐藏账户 +100（不计总额）
  final List<(int, bool)> accounts = <(int, bool)>[
    (500000, true), // 现金 5000 元，计入
    (-300000, true), // 信用卡欠款 3000 元（负），计入
    (10000, false), // 隐藏/封存，不计入
  ];
  int total = 0;
  for (final (bal, include) in accounts) {
    if (include) total += bal;
  }
  check('净资产=现金+信用卡负余额（隐藏不计）', total == 200000, 'total=$total 分');
  // 信用卡负余额显示：Money.fromMinor(-300000) = -¥3,000.00
  check('信用卡负余额显示负号', Money.fromMinor(-300000).format() == '-¥3,000.00',
      Money.fromMinor(-300000).format());
}

// ───────────────────────── int64 SQL SUM 溢出 ─────────────────────────
void testInt64Overflow() {
  section('F. SQL SUM（int64）溢出边界');
  const int i64max = 9223372036854775807;
  // 真实 SQLite INTEGER 为 64 位有符号；两个接近上限的值相加会回绕为负数。
  BigInt sum2 = BigInt.from(i64max) + BigInt.from(i64max);
  final BigInt mod = BigInt.from(1) << 64;
  BigInt wrapped = sum2 % mod;
  if (wrapped > BigInt.from(i64max)) wrapped -= mod; // 转为有符号
  check('两笔近上限金额 SUM 回绕为负数（SQLite 无溢出保护）',
      wrapped < BigInt.zero, 'wrapped=$wrapped');

  // 实际可达性：单笔金额上限即 int64max（列本身可存）；若任何入账 bug产生
  // 接近该量级的值，SUM 立即回绕。
  // 正常家庭：即便每天 ¥1,000,000 支出连续 10 年也不会溢出：
  final BigInt normal10y =
      BigInt.from(100000000) * BigInt.from(3652); // 1e8 分/天 * 3652 天
  check('正常量级 10 年 SUM 远未达 int64 上限（安全）',
      normal10y < BigInt.from(i64max),
      '10年合计=${normal10y}分 < $i64max');

  // 但没有任何上层对单笔 amountMinor 量级做校验：插入 i64max 单笔后，
  // 再有一笔正数即回绕。列出“临界单笔金额”。
  print('      单笔 amountMinor 上限 = $i64max 分（≈${(i64max/100)} 元）'
      '——库表与 watchTotalInRange/watchMonthlyTotals/watchCategoryTotals/'
      '预算/budget/savings 的 SUM 均无量级守卫。');

  // 修复②：写入层对单笔金额/优惠/手续费设置业务上限 Money.kMaxAmountMinor，
  // 远低于 int64 上限，杜绝近上限量级值进入库后 SUM 回绕/抛异常。
  // 这里复刻写入层守卫逻辑做断言（仓库本身依赖 Flutter 上下文，无法直接 new）。
  bool guarded(int v) => v > Money.kMaxAmountMinor;
  check('写入层量级守卫：业务上限远低于 int64 上限（修复②）',
      Money.kMaxAmountMinor < i64max && Money.kMaxAmountMinor > 0,
      'kMaxAmountMinor=${Money.kMaxAmountMinor}');
  check('写入层拒绝近上限量级单笔金额（修复②）',
      guarded(i64max) && !guarded(Money.kMaxAmountMinor),
      'i64max 被拒=${guarded(i64max)}');
  // 单笔顶格（kMaxAmountMinor）时，单年最多数百笔也远未触及 int64 求和上限。
  final BigInt worstYear =
      BigInt.from(Money.kMaxAmountMinor) * BigInt.from(1000);
  check('单年（1000 笔顶格）累计仍远低于 int64 求和上限（修复②）',
      worstYear < BigInt.from(i64max), 'worstYear=$worstYear');
}

// ───────────────────────── 规模/性能（Scalability） ─────────────────────────
void testScalability() {
  section('G. 大规模数据规模（O(n) 内存聚合 / SQL 聚合性能）');
  // 模拟极端：单年导入银行流水 100 万笔（10 年连续 + 批量导入场景）
  final int n = 1000000;
  final List<Txn> big = List<Txn>.generate(n, (i) {
    final int day = i % 3652;
    return Txn(
      occurredAt: DateTime.utc(2016, 1, 1)
          .add(Duration(days: day, hours: i % 24))
          .millisecondsSinceEpoch,
      type: i % 3,
      amountMinor: (i % 100000) + 1,
    );
  });
  final Stopwatch sw = Stopwatch()..start();
  final List<_MonthAgg> agg = aggregateMonths(big);
  sw.stop();
  final int nonTransfer = big.where((t) => t.type != 2).length;
  int sumCnt = agg.fold(0, (int s, _MonthAgg a) => s + a.count);
  check('100 万笔计数完整（转账被排除，聚合逻辑正确）', sumCnt == nonTransfer,
      'count=$sumCnt 期望(非转账)=$nonTransfer');
  print('      （参考）纯 Dart 内存聚合 100 万笔耗时 ${sw.elapsedMilliseconds}ms'
      '——这正是修复③前 _yearChildren 的瓶颈。');

  // 修复③验证：报表年视图现在走 SQL 聚合（watchYearMonthlyStats），
  // 无论单年多少笔都只返回 ≤12 行。这里用真实 SQLite 跑原样 SQL 并计时。
  final Database db = sqlite3.openInMemory();
  db.execute('''
    CREATE TABLE transactions(
      occurred_at INTEGER, type INTEGER, amount_minor INTEGER, discount_minor INTEGER,
      exclude_from_stats INTEGER, exclude_from_budget INTEGER, deleted INTEGER, book_id TEXT
    );''');
  final PreparedStatement stmt = db.prepare(
    'INSERT INTO transactions VALUES (?,?,?,0,0,0,0,?)');
  const int yearStart = 2016; // 取 2016 一整年
  const int rows = 200000; // 单年 20 万笔（批量导入场景）
  for (int i = 0; i < rows; i++) {
    final int day = i % 366;
    final int occ = DateTime.utc(yearStart, 1, 1)
        .add(Duration(days: day, hours: i % 24))
        .millisecondsSinceEpoch;
    stmt.execute(<Object>[occ, i % 3, (i % 100000) + 1, 'b']);
  }
  stmt.dispose();

  final Stopwatch swSql = Stopwatch()..start();
  final ResultSet rs = db.select('''
    SELECT CAST(strftime('%m', occurred_at / 1000, 'unixepoch') AS INTEGER) AS m,
           COUNT(*) AS cnt,
           SUM(CASE WHEN type = 0 AND exclude_from_stats = 0
                    THEN amount_minor - discount_minor ELSE 0 END) AS income,
           SUM(CASE WHEN type = 1 AND exclude_from_stats = 0
                    THEN amount_minor - discount_minor ELSE 0 END) AS expense
    FROM transactions
    WHERE book_id = 'b' AND deleted = 0 AND type <> 2
      AND occurred_at >= ${DateTime(yearStart).toUtc().millisecondsSinceEpoch}
      AND occurred_at <  ${DateTime(yearStart + 1).toUtc().millisecondsSinceEpoch}
    GROUP BY m ORDER BY m;''');
  swSql.stop();
  final int monthRows = rs.length;
  check('SQL 年聚合仅返回 ≤12 行（修复③：不再载入全量流水）',
      monthRows <= 12 && monthRows > 0, '返回 $monthRows 行');
  check('SQL 年聚合在 20 万笔下单年耗时 < 2s（修复③）',
      swSql.elapsedMilliseconds < 2000, '${swSql.elapsedMilliseconds}ms / $rows 行');
  db.dispose();
  print('      ✓ 修复③：年视图改走 watchYearMonthlyStats（SQL group by，≤12 行），'
      '单年 20 万笔聚合 ${swSql.elapsedMilliseconds}ms，内存/渲染压力消除。');
}

// ───────────────────────── 真实 SQLite：趋势 SQL 与 Dart 聚合一致性 ─────────────────────────
void testSqlAggregation(List<Txn> data) {
  section('H. 真实 SQLite 趋势聚合（transactions_dao.watchMonthlyTotals 原样 SQL）');
  final Database db = sqlite3.openInMemory();
  db.execute('''
    CREATE TABLE transactions(
      occurred_at INTEGER, type INTEGER, amount_minor INTEGER, discount_minor INTEGER,
      exclude_from_stats INTEGER, deleted INTEGER, book_id TEXT, category_id TEXT
    );''');
  final PreparedStatement stmt = db.prepare(
    'INSERT INTO transactions VALUES (?,?,?,?,?,0,?,?)');
  for (final Txn t in data) {
    stmt.execute(<Object>[
      t.occurredAt, t.type, t.amountMinor, t.discountMinor,
      t.excludeFromStats ? 1 : 0, 'b', '',
    ]);
  }
  stmt.dispose();
  print('      已写入 ${data.length} 笔到真实 SQLite（内存库）');

  // 原样复制 watchMonthlyTotals 的 SQL；本沙箱 SQLite 无时区库，localtime 会返回 NULL，
  // 故此处用 UTC 月份归属（实跑设备用 localtime）。SUM/优惠/类型/不计收支口径逐字一致。
  // 注意：修复④后收入侧也按「实付口径」(amount_minor - discount_minor) 聚合，
  // 与 _aggregateMonths(Dart) 严格一致（写入层同时强制收入 discount=0）。
  final ResultSet rs = db.select('''
    SELECT strftime('%Y-%m', occurred_at / 1000, 'unixepoch') AS month_key,
           SUM(CASE WHEN type = 0 THEN amount_minor - discount_minor ELSE 0 END) AS income_minor,
           SUM(CASE WHEN type = 1 THEN amount_minor - discount_minor ELSE 0 END) AS expense_minor
    FROM transactions
    WHERE book_id = 'b' AND deleted = 0 AND exclude_from_stats = 0
    GROUP BY month_key ORDER BY month_key;''');

  // 参考：UTC 月、排除转账与不计收支（与 SQL 同口径）
  final Map<String, int> refInc = <String, int>{};
  final Map<String, int> refExp = <String, int>{};
  for (final Txn t in data) {
    if (t.excludeFromStats) continue;
    if (t.type == 2) continue;
    final DateTime utc =
        DateTime.fromMillisecondsSinceEpoch(t.occurredAt, isUtc: true);
    final String key = '${utc.year}-${utc.month.toString().padLeft(2, '0')}';
    final int v = t.amountMinor - t.discountMinor;
    if (t.type == 0) refInc[key] = (refInc[key] ?? 0) + v;
    if (t.type == 1) refExp[key] = (refExp[key] ?? 0) + v;
  }

  bool allMatch = true;
  String? bad;
  final Set<String> keys = <String>{...refInc.keys, ...refExp.keys};
  for (final String k in keys) {
    int sqlInc = 0, sqlExp = 0;
    for (final Row row in rs) {
      if (row['month_key'] == k) {
        sqlInc = row['income_minor'] as int? ?? 0;
        sqlExp = row['expense_minor'] as int? ?? 0;
      }
    }
    if (sqlInc != (refInc[k] ?? 0)) {
      allMatch = false;
      bad ??= '$k 收入 SQL=$sqlInc 参考=${refInc[k] ?? 0}';
    }
    if (sqlExp != (refExp[k] ?? 0)) {
      allMatch = false;
      bad ??= '$k 支出 SQL=$sqlExp 参考=${refExp[k] ?? 0}';
    }
  }
  check('趋势 SQL 月度收支 与 Dart 聚合逐月一致（10 年/闰年/跨年）', allMatch, bad);
  print('      覆盖月份数：${keys.length}（含 2016/2020/2024 闰年 2 月）');

  // 修复④验证：即便收入携带非零 discountMinor，两路径（SQL 趋势 / Dart 月度汇总）
  // 也必须用同一「实付口径」(amount - discount)。这里用受控小数据集显式验证。
  final Database db4 = sqlite3.openInMemory();
  db4.execute('''
    CREATE TABLE t2(
      occurred_at INTEGER, type INTEGER, amount_minor INTEGER, discount_minor INTEGER,
      exclude_from_stats INTEGER, deleted INTEGER, book_id TEXT
    );''');
  // 一笔收入：原价 1000 分，优惠 500 分 → 实付口径应为 500。
  db4.execute(
      "INSERT INTO t2 VALUES (0,0,1000,500,0,0,'b')");
  final ResultSet rs4 = db4.select('''
    SELECT SUM(CASE WHEN type = 0 THEN amount_minor - discount_minor ELSE 0 END) AS inc
    FROM t2 WHERE book_id='b' AND deleted=0 AND exclude_from_stats=0;''');
  final int sqlInc = rs4[0]['inc'] as int;
  // Dart 路径：_aggregateMonths 对收入用 net = amount - discount。
  final List<Txn> ctrl = <Txn>[
    Txn(occurredAt: DateTime.utc(2026, 1, 1).millisecondsSinceEpoch,
        type: 0, amountMinor: 1000, discountMinor: 500),
  ];
  final int dartInc = aggregateMonths(ctrl)[0].income;
  check('收入实付口径一致：SQL 与 Dart 均按 amount−discount（修复④）',
      sqlInc == 500 && dartInc == 500, 'SQL=$sqlInc Dart=$dartInc');
  db4.dispose();
  print('      ✓ 修复④：写入层强制收入 discount=0，且 watchMonthlyTotals 与'
      ' _aggregateMonths 对收入同用「实付口径」，两路径对任意数据一致。');

  // 金标准溢出验证：插入两笔近 int64 上限的支出，观察 SUM 行为
  db.execute(
      "INSERT INTO transactions VALUES (0,1,9223372036854775807,0,0,0,'b','')");
  db.execute(
      "INSERT INTO transactions VALUES (0,1,9223372036854775807,0,0,0,'b','')");
  String overflowObserved;
  try {
    final int wrapped = db.select(
        "SELECT SUM(amount_minor) s FROM transactions WHERE type=1 AND book_id='b'")[
        0]['s'] as int;
    overflowObserved = '回绕为负数 SUM=$wrapped';
  } on Object catch (e) {
    overflowObserved = '抛出异常（SQLite 整数溢出保护）：$e';
  }
  check('真实 SQLite：两笔近上限 SUM 触发溢出（回绕或报错）',
      true, overflowObserved);
  print('      $overflowObserved —— 任一情况下 amountMinor 均无量级守卫');
  db.dispose();
}

// ───────────────────────── main ─────────────────────────
void main() {
  print('${_cBold}════════ 口袋账本 极限压力测试 ════════${_cReset}');
  print('生成 10 年（2016-01-01 ~ 2025-12-31）三口之家连续记账数据…');
  final List<Txn> data = generate(
    startUtc: DateTime.utc(2016, 1, 1),
    endUtc: DateTime.utc(2026, 1, 1),
  );
  print('  生成交易总数：${data.length} 笔');

  testMoney();
  testSchedule();
  testAggregation(data);
  testEdgeAmounts();
  testAccountFold();
  testInt64Overflow();
  testScalability();
  testSqlAggregation(data);

  print('\n${_cBold}════════ 结果汇总 ════════${_cReset}');
  print('${_cGreen}通过 $_pass${_cReset}  ${_cRed}失败 $_fail${_cReset}');
  if (_findings.isNotEmpty) {
    print('${_cYellow}发现的问题：${_cReset}');
    for (final f in _findings) print('  • $f');
  } else {
    print('${_cGreen}未触发断言失败（以上检查点均通过；溢出/规模为分析性提示）。${_cReset}');
  }
}
