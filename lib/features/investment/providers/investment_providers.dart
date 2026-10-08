import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../features/ledger/providers/ledger_providers.dart';
import '../../../providers/app_providers.dart';
import '../data/investment_repository.dart';

final Provider<InvestmentRepository> investmentRepositoryProvider =
    Provider<InvestmentRepository>(
  (Ref ref) => InvestmentRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(transactionRepositoryProvider),
  ),
);

final StreamProvider<List<InvestmentHolding>> investmentListProvider =
    StreamProvider<List<InvestmentHolding>>(
  (Ref ref) => ref
      .watch(investmentRepositoryProvider)
      .watch(ref.watch(currentBookIdProvider)),
);

/// 组合层面的汇总：总市值 / 总成本 / 浮动盈亏。
typedef PortfolioSummary = ({
  int marketValueMinor,
  int costValueMinor,
  int profitMinor,
  double profitRatio,
});

final Provider<PortfolioSummary> portfolioSummaryProvider =
    Provider<PortfolioSummary>((Ref ref) {
  final List<InvestmentHolding> holdings =
      ref.watch(investmentListProvider).valueOrNull ??
          const <InvestmentHolding>[];

  int market = 0;
  int cost = 0;
  for (final InvestmentHolding h in holdings) {
    market += h.marketValueMinor;
    cost += h.costValueMinor;
  }
  final int profit = market - cost;

  return (
    marketValueMinor: market,
    costValueMinor: cost,
    profitMinor: profit,
    profitRatio: cost == 0 ? 0.0 : profit / cost,
  );
});

/// 按账户 ID 聚合的持仓市值（分）：key = [InvestmentHoldings.accountId]。
///
/// 仅统计未删除持仓。证券/投资类账户的「展示余额」= 现金余额 + 本 map 对应值。
/// 与 [portfolioSummaryProvider] 同款模式：由 [investmentListProvider] 派生，
/// 持仓变化时自动重算。普通（非投资类）账户不进此 map。
final Provider<Map<String, int>> investmentMarketValueByAccountProvider =
    Provider<Map<String, int>>((Ref ref) {
  final List<InvestmentHolding> holdings =
      ref.watch(investmentListProvider).valueOrNull ??
          const <InvestmentHolding>[];
  final Map<String, int> map = <String, int>{};
  for (final InvestmentHolding h in holdings) {
    final String? accId = h.accountId;
    if (accId == null) continue;
    map[accId] = (map[accId] ?? 0) + h.marketValueMinor;
  }
  return map;
});

/// 是否证券/投资类账户（基金/股票/期货/现货/定期等，持仓市值需并入展示余额）。
bool isSecuritiesAccount(Account a) =>
    a.type.category == AccountCategory.investment;

/// 账户「展示余额」（分）= 现金余额 + 名下持仓市值合计。
///
/// 普通账户直接返回现金余额（market 为 null/0 时退化为 balanceMinor）。
/// 这是「现金 + 市值」双层模型的唯一口径：存储层只记现金（balanceMinor），
/// 展示层一律经此函数并入口径，避免多处各自加市值导致漂移。
int displayBalanceWithMarket(Account a, Map<String, int>? mv) {
  if (!isSecuritiesAccount(a)) return a.balanceMinor;
  final int market = mv == null ? 0 : (mv[a.id] ?? 0);
  return a.balanceMinor + market;
}
