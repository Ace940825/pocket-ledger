import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_utils.dart';
import '../../../database/app_database.dart';
import '../../../database/daos/transactions_dao.dart';
import '../../../domain/enums.dart';
import '../../../providers/app_providers.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../../inventory/providers/inventory_providers.dart';
import '../../investment/data/investment_repository.dart';
import '../../investment/providers/investment_providers.dart';
import '../../lend/providers/lend_providers.dart';
import '../../ledger/providers/ledger_providers.dart'
    show LedgerAdvancedFilter, LedgerPeriod;
import '../data/report_repository.dart';

/// 报表统计分支：月支出 / 月收入 / 其他（不计收支 + 转账）。
enum ReportBranch { expense, income, other }

/// 报表页高级筛选状态（与账单页的 ledgerAdvancedFilterProvider 互不影响，
/// 「查询」带回结果后触发报表聚合刷新）。
final StateProvider<LedgerAdvancedFilter?> reportAdvancedFilterProvider =
    StateProvider<LedgerAdvancedFilter?>((Ref ref) => null);

final Provider<ReportRepository> reportRepositoryProvider =
    Provider<ReportRepository>(
  (Ref ref) => ReportRepository(ref.watch(transactionsDaoProvider)),
);

/// 报表页当前查看的周期（本地时区；[LedgerPeriod.end] 为开区间）。
/// 默认当前自然月；与账单页的 ledgerPeriodProvider 互不影响。
final StateProvider<LedgerPeriod> reportPeriodProvider =
    StateProvider<LedgerPeriod>((Ref ref) {
  final DateTime now = DateTime.now();
  return LedgerPeriod.monthOf(DateTime(now.year, now.month));
});

/// 报表周期的 UTC 毫秒区间 [startAt, endAt)。
final Provider<({int startAt, int endAt})> reportPeriodRangeProvider =
    Provider<({int startAt, int endAt})>((Ref ref) {
  final LedgerPeriod p = ref.watch(reportPeriodProvider);
  return (
    startAt: p.start.toUtc().millisecondsSinceEpoch,
    endAt: p.end.toUtc().millisecondsSinceEpoch,
  );
});

/// 报表周期的**全部**流水（含转账、不计收支项），环形图/明细聚合用。
/// 口径与账单页 monthTransactionsProvider 一致，只是区间跟随报表周期。
final AutoDisposeStreamProvider<List<Transaction>>
    reportPeriodTransactionsProvider =
    StreamProvider.autoDispose<List<Transaction>>((Ref ref) {
  final String bookId = ref.watch(currentBookIdProvider);
  final ({int startAt, int endAt}) range =
      ref.watch(reportPeriodRangeProvider);
  return ref.watch(transactionsDaoProvider).watchRange(
        bookId: bookId,
        startAt: range.startAt,
        endAt: range.endAt,
      );
});

/// 报表「日历」Tab 当前查看的年份（本地时区）。
final StateProvider<int> reportCalendarYearProvider =
    StateProvider<int>((Ref ref) => DateTime.now().year);

/// 报表「日历」Tab 当前形态：null = 年视图；1~12 = 该月月视图。
/// 提升为 provider 以便「报表 / 日历」两个 Tab 双向同步时间。
final StateProvider<int?> reportCalendarMonthProvider =
    StateProvider<int?>((Ref ref) => null);

/// 日历 Tab 年份的**全部**流水（含转账、不计收支项），月宫格/年账单明细聚合用。
final AutoDisposeStreamProvider<List<Transaction>>
    reportCalendarYearTransactionsProvider =
    StreamProvider.autoDispose<List<Transaction>>((Ref ref) {
  final int y = ref.watch(reportCalendarYearProvider);
  final String bookId = ref.watch(currentBookIdProvider);
  return ref.watch(transactionsDaoProvider).watchRange(
        bookId: bookId,
        startAt: DateTime(y).toUtc().millisecondsSinceEpoch,
        endAt: DateTime(y + 1).toUtc().millisecondsSinceEpoch,
      );
});

/// 近 [months] 个月的收支趋势，按月升序。
///
/// 只查一次库（SQL 层 group by），不是循环 12 次区间查询。
final ProviderFamily<Stream<List<MonthTotal>>, int> monthlyTrendProvider =
    Provider.family<Stream<List<MonthTotal>>, int>((Ref ref, int months) {
  final DateTime now = DateTime.now();
  // 从 N-1 个月前的 1 号开始，保证首月数据完整而不是被截断。
  final DateTime start = DateTime(now.year, now.month - (months - 1));
  final DateTime end = DateTime(now.year, now.month + 1);

  return ref.watch(reportRepositoryProvider).watchMonthlyTotals(
        bookId: ref.watch(currentBookIdProvider),
        startAt: start.toUtc().millisecondsSinceEpoch,
        endAt: end.toUtc().millisecondsSinceEpoch,
      );
});

/// 本月的模块支出分布（钱花在哪些模块）。
final AutoDisposeStreamProvider<List<ModuleTotal>> moduleTotalsProvider =
    StreamProvider.autoDispose<List<ModuleTotal>>((Ref ref) {
  final DateTime now = DateTime.now();
  final ({int start, int end}) range = budgetRange(
    year: now.year,
    periodIndex: now.month,
    monthly: true,
    quarterly: false,
  );
  return ref.watch(reportRepositoryProvider).watchModuleTotals(
        bookId: ref.watch(currentBookIdProvider),
        startAt: range.start,
        endAt: range.end,
      );
});

/// 资产负债总览。
///
/// 口径说明（避免重复计算）：
/// - **资产** = 非负债方向账户余额 + 投资市值 + 物品现值。
///   账户余额本身已包含买股票/买物品花出去的钱的「剩余部分」，
///   而投资市值与物品现值是**独立于账户余额**的资产形态，
///   所以三者相加；若某笔投资资金来自某个已记账账户，用户应把该账户
///   余额视为「现金类」，不会重复计入。
/// - **负债** = 负债方向账户（debt + payable）正余额合计 + 未结清的借入
///   （borrowIn）净额（本金 − 优惠 − 已还）。信用卡正余额=欠款，必须计入
///   负债而不是资产；多还形成的负余额（溢缴款）计回资产。
/// - **净资产** = 资产 - 负债。
typedef NetWorth = ({
  int assetsMinor,
  int liabilitiesMinor,
  int netMinor,
  int accountMinor,
  int investmentMinor,
  int inventoryMinor,
});

/// 注意：这里用 `autoDispose` —— 因为依赖了同为 autoDispose 的
/// `accountsProvider`，而 Riverpod 禁止非 autoDispose 的 provider
/// 依赖 autoDispose 的 provider（生命周期不匹配，运行时会抛断言）。
final AutoDisposeProvider<NetWorth> netWorthProvider =
    Provider.autoDispose<NetWorth>((Ref ref) {
  final List<Account> accounts =
      ref.watch(accountsProvider).valueOrNull ?? const <Account>[];
  final List<InvestmentHolding> holdings =
      ref.watch(investmentListProvider).valueOrNull ??
          const <InvestmentHolding>[];
  final List<InventoryItem> items =
      ref.watch(inventoryListProvider).valueOrNull ?? const <InventoryItem>[];
  final List<LendRecord> lends =
      ref.watch(lendListProvider).valueOrNull ?? const <LendRecord>[];

  int accountMinor = 0;
  int debtAccountMinor = 0;
  for (final Account a in accounts) {
    if (a.type.isLiabilitySide) {
      // 约定：负债方向账户正余额=欠款，计入负债；负余额（多还/溢缴款）计回资产。
      if (a.balanceMinor > 0) {
        debtAccountMinor += a.balanceMinor;
      } else {
        accountMinor -= a.balanceMinor;
      }
    } else {
      accountMinor += a.balanceMinor;
    }
  }

  int investmentMinor = 0;
  for (final InvestmentHolding h in holdings) {
    investmentMinor += h.marketValueMinor;
  }

  int inventoryMinor = 0;
  for (final InventoryItem i in items) {
    inventoryMinor += i.currentValueMinor;
  }

  int liabilitiesMinor = debtAccountMinor;
  for (final LendRecord l in lends) {
    if (l.direction == LendDirection.borrowIn &&
        l.status == LendStatus.ongoing) {
      // 已还与优惠（减免）部分从负债中扣除。
      liabilitiesMinor +=
          (l.amountMinor - l.discountMinor - l.repaidMinor).clamp(0, 1 << 31);
    }
  }

  final int assets = accountMinor + investmentMinor + inventoryMinor;
  return (
    assetsMinor: assets,
    liabilitiesMinor: liabilitiesMinor,
    netMinor: assets - liabilitiesMinor,
    accountMinor: accountMinor,
    investmentMinor: investmentMinor,
    inventoryMinor: inventoryMinor,
  );
});
