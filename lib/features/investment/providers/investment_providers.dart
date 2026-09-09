import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../providers/app_providers.dart';
import '../data/investment_repository.dart';

final Provider<InvestmentRepository> investmentRepositoryProvider =
    Provider<InvestmentRepository>(
  (Ref ref) => InvestmentRepository(ref.watch(appDatabaseProvider)),
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
