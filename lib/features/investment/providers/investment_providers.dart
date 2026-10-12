import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
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

/// 持仓买入/卖出派生日期（不落库，从买卖流水实时推导）：
/// 持仓 id → (首次买入日, 最近卖出日)。买入 = 最早支出流水，卖出 = 最晚收入流水。
final StreamProvider<Map<String, (DateTime?, DateTime?)>>
    investmentFlowDatesProvider =
    StreamProvider<Map<String, (DateTime?, DateTime?)>>((Ref ref) {
  return ref
      .watch(transactionsDaoProvider)
      .watchAllInvestmentFlows(bookId: ref.watch(currentBookIdProvider))
      .map((List<Transaction> flows) {
    final Map<String, (DateTime?, DateTime?)> out =
        <String, (DateTime?, DateTime?)>{};
    for (final Transaction f in flows) {
      final String? hid = f.relatedId;
      if (hid == null) continue;
      final DateTime d = DateTime.fromMillisecondsSinceEpoch(
        f.occurredAt,
        isUtc: true,
      ).toLocal();
      var (DateTime? buy, DateTime? sell) = out[hid] ?? (null, null);
      if (f.type == TxnType.expense) {
        if (buy == null || d.isBefore(buy)) buy = d;
      } else if (f.type == TxnType.income) {
        if (sell == null || d.isAfter(sell)) sell = d;
      }
      out[hid] = (buy, sell);
    }
    return out;
  });
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

/// 投资类账户现金余额合计（分）：总资产「现金」侧。
///
/// 投资账户存储层 [Account.balanceMinor] 只记现金（市值在展示层叠加），
/// 总资产 = 本值 + 持仓市值合计。直接订阅 accountsDao（不经 accounts_providers，
/// 避免循环 import），口径与 [isSecuritiesAccount] 一致。
final StreamProvider<int> investmentCashProvider = StreamProvider<int>((
  Ref ref,
) {
  final String bookId = ref.watch(currentBookIdProvider);
  return ref
      .watch(accountsDaoProvider)
      .watchByBook(bookId)
      .map((List<Account> list) {
    int cash = 0;
    for (final Account a in list) {
      if (isSecuritiesAccount(a)) cash += a.balanceMinor;
    }
    return cash;
  });
});

/// 累计买入成本（分）：账本内全部投资买入流水的净额合计（金额 − 手续费）。
///
/// 收益率的分母（全周期口径）：清仓持仓的买入也计入，保证清仓前后
/// 收益率口径一致。与 [investedCostMinorFor] 同公式（单持仓版）。
final StreamProvider<int> investedCostProvider = StreamProvider<int>((Ref ref) {
  final String bookId = ref.watch(currentBookIdProvider);
  return ref
      .watch(transactionsDaoProvider)
      .watchAllInvestmentFlows(bookId: bookId)
      .map((List<Transaction> flows) => investedCostMinorFor(flows));
});

/// 每持仓的轮次划分（已完成轮 + 当前轮）：持仓/清仓双卡与汇总口径的数据源。
///
/// 直接订阅全量投资流水，按 [Transaction.relatedId] 分组后逐持仓 [replayHoldCycles]。
/// 清仓后再买入会开新一轮——当前轮只含本轮成本/盈亏，历史清仓收益在 [HoldingCycleInfo.completed]。
final StreamProvider<Map<String, HoldingCycleInfo>>
    investmentCycleInfoProvider =
    StreamProvider<Map<String, HoldingCycleInfo>>((Ref ref) {
  final String bookId = ref.watch(currentBookIdProvider);
  return ref
      .watch(transactionsDaoProvider)
      .watchAllInvestmentFlows(bookId: bookId)
      .map((List<Transaction> flows) {
    final Map<String, List<Transaction>> byHolding =
        <String, List<Transaction>>{};
    for (final Transaction f in flows) {
      final String? hid = f.relatedId;
      if (hid == null) continue;
      (byHolding[hid] ??= <Transaction>[]).add(f);
    }
    final Map<String, HoldingCycleInfo> out = <String, HoldingCycleInfo>{};
    byHolding.forEach((String hid, List<Transaction> hf) {
      final (List<HoldCycle> completed, HoldCycle? open) = replayHoldCycles(hf);
      out[hid] = HoldingCycleInfo(completed: completed, open: open);
    });
    return out;
  });
});

/// 组合层面的汇总：总资产 / 总市值 / 现金 / 仓位 / 摊薄总成本 / 总盈亏（全周期）/ 收益率。
typedef PortfolioSummary = ({
  int marketValueMinor, // 持仓市值合计
  int cashMinor, // 投资类账户现金合计
  int totalAssetMinor, // 总资产 = 现金 + 持仓市值
  double positionRatio, // 仓位 = 持仓市值 ÷ 总资产（总资产为 0 时返回 0）
  int costValueMinor, // 摊薄总成本（仅当前轮）= 当前轮持仓成本 − 当前轮已实现
  int profitMinor, // 总盈亏（全周期）= 当前轮利润 + 全部历史清仓收益
  double profitRatio, // 收益率 = 总盈亏 ÷ 累计买入成本（全周期口径）
  int investedCostMinor, // 累计买入成本（含清仓持仓，收益率分母）
  int realizedProfitMinor, // 持仓收益（当前轮部分清仓 + 全部历史清仓落袋）
});

/// 组合层面的汇总：总资产 / 总市值 / 现金 / 仓位 / 摊薄总成本 / 总盈亏 / 收益率。
///
/// 总资产 = 投资类账户现金 + 持仓市值（「现金 + 市值」双层模型，见
/// [investmentCashProvider]）；仓位 = 市值 ÷ 总资产。
/// **按轮次口径（[investmentCycleInfoProvider]）**：未清仓持仓只取当前轮成本/盈亏
/// （不含历史清仓包袱），清仓持仓回落为历史累计落仓收益——保证「清仓后再买入」
/// 后持仓卡盈亏不被旧一轮拖累，而组合总盈亏仍含全部历史（复盘可见）。
/// **收益率 = 总盈亏 ÷ 累计买入成本**（[investedCostProvider]，含清仓持仓全周期），
/// 分母为真实总投入，清仓前后口径一致。
final Provider<PortfolioSummary> portfolioSummaryProvider =
    Provider<PortfolioSummary>((Ref ref) {
  final List<InvestmentHolding> holdings =
      ref.watch(investmentListProvider).valueOrNull ??
          const <InvestmentHolding>[];
  final int cash = ref.watch(investmentCashProvider).valueOrNull ?? 0;
  final int invested = ref.watch(investedCostProvider).valueOrNull ?? 0;
  final Map<String, HoldingCycleInfo> cyc =
      ref.watch(investmentCycleInfoProvider).valueOrNull ??
          const <String, HoldingCycleInfo>{};

  int market = 0;
  int cost = 0;
  int profit = 0;
  int realized = 0;
  for (final InvestmentHolding h in holdings) {
    market += h.marketValueMinor;
    final HoldingCycleInfo? info = cyc[h.id];
    final HoldCycle? open = info?.open;
    if (open != null && h.quantityMicros > 0) {
      // 当前轮（不含历史）：成本只看这一轮；总盈亏 = 当前轮利润 + 全部历史清仓收益
      // （保证「清仓后再买入」后首页仍含历史落袋盈亏，复盘可见）。
      final int dilutedCost = open.dilutedCostValueMinor;
      cost += dilutedCost;
      profit += open.dilutedProfitMinor(h.marketValueMinor) +
          info!.historyRealizedMinor;
      realized += open.realizedMinor + info.historyRealizedMinor;
    } else {
      // 清仓或异常：回落为历史累计落袋收益（全周期）。
      profit += h.realizedProfitMinor;
      realized += h.realizedProfitMinor;
    }
  }
  final int totalAsset = cash + market;
  return (
    marketValueMinor: market,
    cashMinor: cash,
    totalAssetMinor: totalAsset,
    positionRatio: totalAsset == 0 ? 0.0 : market / totalAsset,
    costValueMinor: cost,
    profitMinor: profit,
    profitRatio: invested == 0 ? 0.0 : profit / invested,
    investedCostMinor: invested,
    realizedProfitMinor: realized,
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
