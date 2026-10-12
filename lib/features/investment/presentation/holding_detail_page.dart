import 'package:flutter/material.dart';
import 'package:pocket_ledger/shared/widgets/hairline_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/note_utils.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../shared/models/money.dart';
import '../../../theme/theme.dart';
import '../../ledger/presentation/transaction_detail_sheet.dart';
import '../../ledger/presentation/widgets/transaction_tile.dart';
import '../../ledger/presentation/widgets/txn_slidable.dart';
import '../../../shared/widgets/section_header.dart';
import '../data/investment_repository.dart';
import '../providers/investment_providers.dart';
import 'investment_page.dart';

/// 持仓详情页：顶部持仓信息卡（份额/成本/现价/市值/盈亏），
/// 下方「交易流水」区按时间倒序列出该标的全部买入/卖出流水。
///
/// 入口：投资页点击持仓卡片。编辑持仓/改现价入口收在 AppBar。
class HoldingDetailPage extends ConsumerWidget {
  const HoldingDetailPage({
    super.key,
    required this.holdingId,
    this.historyMode = false,
  });

  final String holdingId;

  /// 历史清仓视图（从「历史清仓」卡进入）：标的仍持仓，但展示累计已完成轮
  /// 口径（成本/总盈亏/收益率/持仓天数/日期）+ 历史轮流水；
  /// false = 当前轮视图（只看当前轮，不显历史）。
  final bool historyMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<InvestmentHolding>> holdings =
        ref.watch(investmentListProvider);
    final InvestmentHolding? holding = holdings.valueOrNull
        ?.where((InvestmentHolding h) => h.id == holdingId)
        .firstOrNull;

    if (holding == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('持仓详情')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final ThemeData theme = Theme.of(context);
    final bool cleared = holding.quantityMicros == 0;
    final bool isDark = theme.brightness == Brightness.dark;
    final int profit = holding.dilutedProfitMinor;
    final Color profitColor = profit > 0
        ? AppPalette.stock(true, dark: isDark)
        : profit < 0
            ? AppPalette.stock(false, dark: isDark)
            : Theme.of(context).colorScheme.onSurfaceVariant;

    final String? updatedLabel = holding.priceUpdatedAt == null
        ? null
        : DateFormat('yyyy-MM-dd HH:mm').format(
            DateTime.fromMillisecondsSinceEpoch(
              holding.priceUpdatedAt!,
              isUtc: true,
            ).toLocal(),
          );

    // 历史清仓视图 / 已清仓（份额 0）显全历史流水；当前持仓视图只显当前轮流水。
    final HoldCycle? openCycle =
        ref.watch(investmentCycleInfoProvider).valueOrNull?[holdingId]?.open;
    final int? roundStartMs = (historyMode || holding.quantityMicros == 0)
        ? null
        : (openCycle != null
            ? openCycle.startedAt.millisecondsSinceEpoch
            : null);

    return Scaffold(
      appBar: AppBar(
        // 与持仓卡同款：名称在前（主字号），代码在后（小一号、次级色）。
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: Text(
                holding.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              holding.symbol,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: '编辑持仓',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showHoldingEditor(context, ref, holding),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: <Widget>[
          _InfoCard(
            holding: holding,
            cleared: cleared,
            historyMode: historyMode,
            profitColor: profitColor,
          ),
          const SizedBox(height: 12),
          if (holding.note != null && holding.note!.isNotEmpty) ...<Widget>[
            _NoteCard(note: holding.note!),
            const SizedBox(height: 12),
          ],
          const SectionHeader(title: '交易流水'),
          const SizedBox(height: 6),
          // 持仓页只显当前轮流水；清仓复盘视图显全历史。
          _FlowList(holdingId: holdingId, roundStartedAtMs: roundStartMs),
          if (updatedLabel != null) ...<Widget>[
            const SizedBox(height: 10),
            Center(
              child: Text(
                '现价更新于 $updatedLabel',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 持仓信息卡：徽章 + 名称 / 份额·成本·现价副行 / 市值 + 总盈亏双大字。
///
/// ConsumerWidget：徽章的 AH 股判定需读全量持仓列表（同名 A股+港股）。
class _InfoCard extends ConsumerWidget {
  const _InfoCard({
    required this.holding,
    required this.cleared,
    required this.profitColor,
    this.historyMode = false,
  });

  final InvestmentHolding holding;

  /// 是否清仓记录（份额 = 0）：徽章显「已清仓」，市值/盈亏为 0。
  final bool cleared;

  /// 历史清仓视图（从「历史清仓」卡进入）：标的仍持仓，但显示累计已完成轮
  /// 口径（成本/总盈亏/收益率/持仓天数/日期）+ 历史轮流水。
  final bool historyMode;

  final Color profitColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final TextTheme t = theme.textTheme;
    final bool isDark = theme.brightness == Brightness.dark;
    // 轮次口径：histView（清仓复盘 / 历史清仓卡进入）= 累计已完成轮；
    // 否则当前持仓 = 只看当前轮（不计历史成本/盈亏）。
    final HoldingCycleInfo? info =
        ref.watch(investmentCycleInfoProvider).valueOrNull?[holding.id];
    final HoldCycle? open = info?.open;
    final List<HoldCycle> rounds = info?.completed ?? const <HoldCycle>[];
    final bool histView = cleared || historyMode;

    final List<Transaction> allFlows =
        ref.watch(holdingFlowsProvider(holding.id)).valueOrNull ??
            const <Transaction>[];

    // 日期 + 持仓天数：历史视图取已完成轮首尾（首次买入 → 最近卖出/清仓时点）；
    // 当前轮视图按轮内流水重算（首次买入 → 现在）。
    DateTime? firstBuyAt;
    DateTime? lastSellAt;
    int holdingDays = -1;
    int histInvested = 0;
    int histAvgCost = 0; // 清仓后单价成本 = 历史累计投入 ÷ 历史累计买入份额
    int costAvgMinor = 0;
    final int profitMinor;
    final double ratio;
    if (histView) {
      if (rounds.isNotEmpty) {
        firstBuyAt = rounds.first.startedAt;
        lastSellAt = rounds.last.endedAt;
        if (lastSellAt != null) {
          holdingDays = lastSellAt.difference(firstBuyAt).inDays.abs();
        }
      }
      histInvested =
          info?.historyInvestedMinor ?? investedCostMinorFor(allFlows);
      // info 缺失时按买入流水兜底累计买入份额。
      int histBoughtQty = info?.historyBoughtQtyMicros ?? 0;
      if (info == null) {
        for (final Transaction f in allFlows) {
          if (f.type == TxnType.expense) {
            histBoughtQty +=
                InvestmentRepository.parseTradeMeta(f.note)?.$3 ?? 0;
          }
        }
      }
      histAvgCost = histBoughtQty == 0
          ? 0
          : (histInvested * InvestmentRepository.quantityScale +
                  histBoughtQty ~/ 2) ~/
              histBoughtQty;
      profitMinor = info?.historyRealizedMinor ?? holding.realizedProfitMinor;
      ratio = histInvested == 0 ? 0.0 : profitMinor / histInvested;
    } else {
      // 当前轮：流水与买卖日期按当前轮起点过滤后重算。
      final int roundStartMs =
          open != null ? open.startedAt.millisecondsSinceEpoch : 0;
      final List<Transaction> roundFlows = roundStartMs <= 0
          ? allFlows
          : allFlows
              .where((Transaction f) => f.occurredAt >= roundStartMs)
              .toList(growable: false);
      for (final Transaction f in roundFlows) {
        final DateTime d = DateTime.fromMillisecondsSinceEpoch(
          f.occurredAt,
          isUtc: true,
        ).toLocal();
        if (f.type == TxnType.expense) {
          if (firstBuyAt == null || d.isBefore(firstBuyAt)) firstBuyAt = d;
        } else if (f.type == TxnType.income) {
          if (lastSellAt == null || d.isAfter(lastSellAt)) lastSellAt = d;
        }
      }
      if (firstBuyAt != null) {
        holdingDays = DateTime.now().difference(firstBuyAt).inDays.abs();
      }
      if (open != null) {
        profitMinor = open.dilutedProfitMinor(holding.marketValueMinor);
        costAvgMinor = open.dilutedAvgCostMinor;
        ratio = open.dilutedProfitRatio(holding.marketValueMinor);
      } else {
        profitMinor = holding.dilutedProfitMinor;
        costAvgMinor = holding.dilutedAvgCostMinor;
        ratio = holding.dilutedProfitRatio;
      }
    }
    // 盈亏颜色以轮次口径的 profitMinor 为准（覆盖传入的摊薄口径色）。
    final Color profitColor = profitMinor > 0
        ? AppPalette.stock(true, dark: isDark)
        : profitMinor < 0
            ? AppPalette.stock(false, dark: isDark)
            : Theme.of(context).colorScheme.onSurfaceVariant;
    // 仓位 = 该持仓市值 ÷ 组合总资产（现金 + 全部持仓市值），见汇总卡口径。
    final PortfolioSummary summary = ref.watch(portfolioSummaryProvider);
    final double positionRatio = summary.totalAssetMinor == 0
        ? 0.0
        : holding.marketValueMinor / summary.totalAssetMinor;
    final Color badgeColor = histView
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : AppPalette.primary;

    Widget metric(String label, String value, {Color? color}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: t.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: t.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: color ?? Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      );
    }

    return HairlineCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    // 历史视图（清仓复盘 / 历史清仓卡）显对应徽章。
                    histView
                        ? (cleared ? '已清仓' : '历史清仓')
                        : investmentTypeLabel(
                            holding.type,
                            holding.symbol,
                            name: holding.name,
                            all: ref.watch(investmentListProvider).valueOrNull,
                          ),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: badgeColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    holding.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      // 历史视图不显持仓市值：大字对 = 累计投入 | 总盈亏。
                      histView ? '累计投入' : '持仓市值',
                      style: t.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Money.fromMinor(
                        histView ? histInvested : holding.marketValueMinor,
                      ).format(),
                      style: t.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      '总盈亏',
                      style: t.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Money.fromMinor(profitMinor).formatSigned(),
                      style: t.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: profitColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (histView) ...<Widget>[
              // 历史视图：成本(清仓单价) | 收益率 | 现价（不显份额/仓位）。
              Row(
                children: <Widget>[
                  Expanded(
                    child: metric(
                      '成本',
                      histAvgCost == 0
                          ? '—'
                          : Money.fromMinor(histAvgCost).format(),
                    ),
                  ),
                  Expanded(
                    child: metric(
                      '收益率',
                      '${(ratio * 100).toStringAsFixed(2)}%',
                      color: profitColor,
                    ),
                  ),
                  Expanded(
                    child: metric(
                      '现价',
                      Money.fromMinor(holding.currentPriceMinor).format(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // 历史视图日期行：持仓天数 | 首次买入 | 最近卖出。
              Row(
                children: <Widget>[
                  Expanded(
                    child: metric(
                      '持仓天数',
                      holdingDays < 0 ? '—' : '$holdingDays 天',
                    ),
                  ),
                  Expanded(
                    child: metric('首次买入', _fmtDay(firstBuyAt)),
                  ),
                  Expanded(
                    child: metric('最近卖出', _fmtDay(lastSellAt)),
                  ),
                ],
              ),
            ] else ...<Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: metric(
                      '持有份额',
                      '${formatQuantity(holding.quantity)} 份',
                    ),
                  ),
                  Expanded(
                    child: metric(
                      '成本单价',
                      Money.fromMinor(costAvgMinor).format(),
                    ),
                  ),
                  Expanded(
                    child: metric(
                      '现价',
                      Money.fromMinor(holding.currentPriceMinor).format(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: metric(
                      '收益率',
                      '${(ratio * 100).toStringAsFixed(2)}%',
                      color: profitColor,
                    ),
                  ),
                  Expanded(
                    child: metric(
                      '仓位',
                      '${(positionRatio * 100).toStringAsFixed(2)}%',
                    ),
                  ),
                  Expanded(
                    // 持仓天数：清仓 = 首次买入 → 最近卖出；持仓中 = 首次买入 → 现在。
                    child: metric(
                      '持仓天数',
                      holdingDays < 0 ? '—' : '$holdingDays 天',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // 当前轮日期行：首次买入 | 最近卖出。
              Row(
                children: <Widget>[
                  Expanded(
                    child: metric('首次买入', _fmtDay(firstBuyAt)),
                  ),
                  Expanded(
                    child: metric('最近卖出', _fmtDay(lastSellAt)),
                  ),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _fmtDay(DateTime? d) =>
      d == null ? '—' : DateFormat('yyyy-MM-dd').format(d);
}

/// 备注卡。
class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: AppPalette.sage50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '备注',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              // 「·」元信息单元不断行：换行只发生在栏目之间，单元内部不拆。
              keepNoteUnitsUnbroken(note),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 交易流水列表：按时间倒序，行样式与账单页一致，点击进明细弹窗。
///
/// [roundStartedAtMs] 非空时只显示当前轮流水（occurredAt >= 轮起点），
/// 供持仓页「不显历史流水」；null/0 = 显示全部（清仓复盘视图）。
class _FlowList extends ConsumerWidget {
  const _FlowList({required this.holdingId, this.roundStartedAtMs});

  final String holdingId;
  final int? roundStartedAtMs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Transaction>> flows =
        ref.watch(holdingFlowsProvider(holdingId));

    return flows.when(
      data: (List<Transaction> list) {
        // 字段不参与类型提升，先落地为局部变量再判空。
        final int? startMs = roundStartedAtMs;
        final List<Transaction> visible = startMs == null || startMs <= 0
            ? list
            : list
                .where((Transaction f) => f.occurredAt >= startMs)
                .toList(growable: false);
        if (visible.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            alignment: Alignment.center,
            child: Text(
              '暂无交易流水，买卖后自动记录',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          );
        }
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TxnSlidableGroup(
            child: Column(
              children: <Widget>[
                for (int i = 0; i < visible.length; i++) ...<Widget>[
                  if (i > 0)
                    Container(
                      height: 0.6,
                      margin: const EdgeInsets.only(left: 52),
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  TxnSlidable(
                    txn: visible[i],
                    child: TransactionTile(
                      transaction: visible[i],
                      onTap: () =>
                          TransactionDetailSheet.show(context, visible[i]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (Object e, StackTrace _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('加载失败：$e')),
      ),
    );
  }
}
