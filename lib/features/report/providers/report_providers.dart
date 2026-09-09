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
import '../data/report_repository.dart';

final Provider<ReportRepository> reportRepositoryProvider =
    Provider<ReportRepository>(
  (Ref ref) => ReportRepository(ref.watch(transactionsDaoProvider)),
);

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
/// - **资产** = 各账户余额 + 投资市值 + 物品现值。
///   账户余额本身已包含买股票/买物品花出去的钱的「剩余部分」，
///   而投资市值与物品现值是**独立于账户余额**的资产形态，
///   所以三者相加；若某笔投资资金来自某个已记账账户，用户应把该账户
///   余额视为「现金类」，不会重复计入。
/// - **负债** = 未结清的借入（borrowIn）金额。
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
      ref.watch(inventoryListProvider).valueOrNull ??
          const <InventoryItem>[];
  final List<LendRecord> lends =
      ref.watch(lendListProvider).valueOrNull ?? const <LendRecord>[];

  int accountMinor = 0;
  for (final Account a in accounts) {
    // 信用卡额度是负债方向，余额为负时自然体现，这里不做特殊处理。
    accountMinor += a.balanceMinor;
  }

  int investmentMinor = 0;
  for (final InvestmentHolding h in holdings) {
    investmentMinor += h.marketValueMinor;
  }

  int inventoryMinor = 0;
  for (final InventoryItem i in items) {
    inventoryMinor += i.currentValueMinor;
  }

  int liabilitiesMinor = 0;
  for (final LendRecord l in lends) {
    if (l.direction == LendDirection.borrowIn &&
        l.status == LendStatus.ongoing) {
      // 已还部分从负债中扣除。
      liabilitiesMinor += (l.amountMinor - l.repaidMinor).clamp(0, 1 << 31);
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
