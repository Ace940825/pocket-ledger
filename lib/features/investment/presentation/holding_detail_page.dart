import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/module_list_scaffold.dart';
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
  const HoldingDetailPage({super.key, required this.holdingId});

  final String holdingId;

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
    final int profit = holding.profitMinor;
    final Color profitColor = profit > 0
        ? AppPalette.stock(true, dark: isDark)
        : profit < 0
            ? AppPalette.stock(false, dark: isDark)
            : AppPalette.textSecondary;

    final String? updatedLabel = holding.priceUpdatedAt == null
        ? null
        : DateFormat('yyyy-MM-dd HH:mm').format(
            DateTime.fromMillisecondsSinceEpoch(
              holding.priceUpdatedAt!,
              isUtc: true,
            ).toLocal(),
          );

    return Scaffold(
      appBar: AppBar(
        title: Text('${holding.symbol}  ${holding.name}'),
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
          _InfoCard(holding: holding, cleared: cleared, profitColor: profitColor),
          const SizedBox(height: 12),
          if (holding.note != null && holding.note!.isNotEmpty) ...<Widget>[
            _NoteCard(note: holding.note!),
            const SizedBox(height: 12),
          ],
          const SectionHeader(title: '交易流水'),
          const SizedBox(height: 6),
          _FlowList(holdingId: holdingId),
          if (updatedLabel != null) ...<Widget>[
            const SizedBox(height: 10),
            Center(
              child: Text(
                '现价更新于 $updatedLabel',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppPalette.textTertiary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 持仓信息卡：徽章 + 名称 / 份额·成本·现价副行 / 市值 + 浮动盈亏双大字。
///
/// ConsumerWidget：徽章的 AH 股判定需读全量持仓列表（同名 A股+港股）。
class _InfoCard extends ConsumerWidget {
  const _InfoCard({
    required this.holding,
    required this.cleared,
    required this.profitColor,
  });

  final InvestmentHolding holding;

  /// 是否清仓记录（份额 = 0）：徽章显「已清仓」，市值/盈亏为 0。
  final bool cleared;
  final Color profitColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final TextTheme t = theme.textTheme;
    final int profit = holding.profitMinor;
    final Color badgeColor = cleared ? AppPalette.textTertiary : AppPalette.primary;

    Widget metric(String label, String value, {Color? color}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: t.bodySmall?.copyWith(color: AppPalette.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: t.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: color ?? AppPalette.textPrimary,
            ),
          ),
        ],
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppPalette.hairline),
      ),
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
                    cleared
                        ? '已清仓'
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
                      color: AppPalette.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: metric(
                    '持有份额',
                    '${holding.quantity.toStringAsFixed(4)} 份',
                  ),
                ),
                Expanded(
                  child: metric(
                    '成本单价',
                    Money.fromMinor(holding.avgCostMinor).format(),
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
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '持仓市值',
                      style: t.bodySmall
                          ?.copyWith(color: AppPalette.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Money.fromMinor(holding.marketValueMinor).format(),
                      style: t.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppPalette.textPrimary,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      '浮动盈亏',
                      style: t.bodySmall
                          ?.copyWith(color: AppPalette.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${Money.fromMinor(profit).formatSigned()}  '
                      '${(holding.profitRatio * 100).toStringAsFixed(2)}%',
                      style: t.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: profitColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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
                color: AppPalette.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              note,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppPalette.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 交易流水列表：按时间倒序，行样式与账单页一致，点击进明细弹窗。
class _FlowList extends ConsumerWidget {
  const _FlowList({required this.holdingId});

  final String holdingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Transaction>> flows =
        ref.watch(holdingFlowsProvider(holdingId));

    return flows.when(
      data: (List<Transaction> list) {
        if (list.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            alignment: Alignment.center,
            child: Text(
              '暂无交易流水，买卖后自动记录',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppPalette.textTertiary,
                  ),
            ),
          );
        }
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppPalette.hairline),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TxnSlidableGroup(
            child: Column(
              children: <Widget>[
                for (int i = 0; i < list.length; i++) ...<Widget>[
                  if (i > 0)
                    Container(
                      height: 0.6,
                      margin: const EdgeInsets.only(left: 52),
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  TxnSlidable(
                    txn: list[i],
                    child: TransactionTile(
                      transaction: list[i],
                      onTap: () =>
                          TransactionDetailSheet.show(context, list[i]),
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
