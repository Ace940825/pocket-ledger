import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../database/daos/transactions_dao.dart';
import '../../../domain/enums.dart';
import '../../../features/ledger/providers/ledger_providers.dart';
import '../../../providers/app_providers.dart';
import '../data/investment_repository.dart';
import '../data/market/market_service.dart';
import '../data/market/security_meta_repository.dart';

/// 单个持仓的买卖流水（持仓详情页「交易流水」区）。
final AutoDisposeStreamProviderFamily<List<Transaction>, String>
    holdingFlowsProvider = StreamProvider.autoDispose
        .family<List<Transaction>, String>((Ref ref, String holdingId) {
  final String bookId = ref.watch(currentBookIdProvider);
  return ref
      .watch(transactionsDaoProvider)
      .watchInvestmentFlows(holdingId, bookId: bookId);
});

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

/// 行情候选库仓储（本地 security_meta 表访问）。
final Provider<SecurityMetaRepository> securityMetaRepositoryProvider =
    Provider<SecurityMetaRepository>(
  (Ref ref) => SecurityMetaRepository(ref.watch(appDatabaseProvider)),
);

/// 行情服务（按品种路由免费第三方源）。
final Provider<MarketService> marketServiceProvider = Provider<MarketService>(
  (Ref ref) => MarketService(ref.watch(securityMetaRepositoryProvider)),
);

/// 自动补全搜索参数（代码/名称关键词 + 限定品种；null = 未选品种，跨品种搜）。
class MetaQuery {
  const MetaQuery(this.q, this.type);
  final String q;
  final InvestmentType? type;

  @override
  bool operator ==(Object other) =>
      other is MetaQuery && other.q == q && other.type == type;

  @override
  int get hashCode => Object.hash(q, type);
}

/// 按关键词搜索行情候选库（本地查，秒级）。
final AutoDisposeFutureProviderFamily<List<SecurityCandidate>, MetaQuery>
    securityMetaSearchProvider = FutureProvider.autoDispose
        .family<List<SecurityCandidate>, MetaQuery>((Ref ref, MetaQuery q) {
  return ref.watch(securityMetaRepositoryProvider).search(q.q, type: q.type);
});

/// 每日行情刷新（遍历全部持仓抓现价落库，内部按本地日节流）。
final FutureProvider<int> refreshPricesProvider = FutureProvider<int>(
  (Ref ref) => ref.watch(investmentRepositoryProvider).refreshAllPrices(),
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
