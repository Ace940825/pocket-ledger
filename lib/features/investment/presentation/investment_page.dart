import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/form_fields.dart';
import '../../../shared/widgets/module_list_scaffold.dart';
import '../data/investment_repository.dart';
import '../providers/investment_providers.dart';

/// 投资页：持仓列表 + 组合盈亏汇总。
///
/// 行情数据不接入任何第三方接口（会产生费用与合规负担），
/// 现价由用户手动录入，配合 [InvestmentRepository.updatePrice] 更新。
class InvestmentPage extends ConsumerWidget {
  const InvestmentPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<InvestmentHolding>> holdings =
        ref.watch(investmentListProvider);

    return ModuleListScaffold<InvestmentHolding>(
      title: '投资',
      items: holdings,
      emptyHint: '还没有持仓，点右下角新增',
      header: holdings.maybeWhen(
        data: (List<InvestmentHolding> _) =>
            const _PortfolioSummaryCard(),
        orElse: () => null,
      ),
      onCreate: () => showHoldingEditor(context, ref),
      itemBuilder: (BuildContext context, InvestmentHolding h) =>
          _HoldingTile(holding: h),
    );
  }
}

/// 组合汇总卡片：总市值 / 总成本 / 浮动盈亏。
class _PortfolioSummaryCard extends ConsumerWidget {
  const _PortfolioSummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PortfolioSummary summary = ref.watch(portfolioSummaryProvider);
    final ThemeData theme = Theme.of(context);

    // 中国区习惯：涨用红、跌用绿。
    final Color profitColor = summary.profitMinor > 0
        ? const Color(0xFFE53935)
        : summary.profitMinor < 0
            ? const Color(0xFF43A047)
            : theme.textTheme.bodyMedium?.color ?? Colors.grey;

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('持仓市值', style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              Money.fromMinor(summary.marketValueMinor).format(),
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _Metric(
                    label: '总成本',
                    value: Money.fromMinor(summary.costValueMinor).format(),
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: '浮动盈亏',
                    value: Money.fromMinor(summary.profitMinor).formatSigned(),
                    color: profitColor,
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: '收益率',
                    value:
                        '${(summary.profitRatio * 100).toStringAsFixed(2)}%',
                    color: profitColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}

/// 单个持仓行：市值、盈亏、快捷改价。
class _HoldingTile extends ConsumerWidget {
  const _HoldingTile({required this.holding});

  final InvestmentHolding holding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final int profit = holding.profitMinor;
    final Color profitColor = profit > 0
        ? const Color(0xFFE53935)
        : profit < 0
            ? const Color(0xFF43A047)
            : Colors.grey;

    return ListTile(
      title: Text('${holding.symbol}  ${holding.name}'),
      subtitle: Text(
        '${holding.type.label} · ${holding.quantity.toStringAsFixed(4)} 份 · '
        '成本 ${Money.fromMinor(holding.avgCostMinor).format()} / 现价 '
        '${Money.fromMinor(holding.currentPriceMinor).format()}'
        '${holding.priceUpdatedAt == null ? '' : '  ·  '
            '${DateFormat('MM-dd HH:mm').format(
              DateTime.fromMillisecondsSinceEpoch(
                holding.priceUpdatedAt!,
                isUtc: true,
              ).toLocal(),
            )}'}',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(
            Money.fromMinor(holding.marketValueMinor).format(),
            style: theme.textTheme.bodyLarge,
          ),
          Text(
            '${Money.fromMinor(profit).formatSigned()}  '
            '${(holding.profitRatio * 100).toStringAsFixed(2)}%',
            style: theme.textTheme.bodySmall?.copyWith(color: profitColor),
          ),
        ],
      ),
      onTap: () => showHoldingEditor(context, ref, holding),
      onLongPress: () => _showPriceEditor(context, ref),
    );
  }

  Future<void> _showPriceEditor(BuildContext context, WidgetRef ref) async {
    final TextEditingController controller = TextEditingController(
      text: Money.fromMinor(holding.currentPriceMinor)
          .decimal
          .toStringAsFixed(4),
    );
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: Text('更新 ${holding.symbol} 现价'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: '现价',
            prefixText: '¥ ',
            helperText: '支持 4 位小数，用于基金净值',
          ),
          autofocus: true,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('更新'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final double? price = double.tryParse(controller.text.trim());
    if (price == null || price < 0) {
      showToast(context, '价格不合法');
      return;
    }
    try {
      await ref
          .read(investmentRepositoryProvider)
          .updatePrice(holding.id, Money.fromDecimal(price).minor);
    } on AppFailure catch (e) {
      if (context.mounted) showToast(context, e.message);
    }
  }
}

/// 持仓新增 / 编辑对话框。
Future<void> showHoldingEditor(
  BuildContext context,
  WidgetRef ref, [
  InvestmentHolding? holding,
]) async {
  final TextEditingController symbolController =
      TextEditingController(text: holding?.symbol ?? '');
  final TextEditingController nameController =
      TextEditingController(text: holding?.name ?? '');
  final TextEditingController quantityController = TextEditingController(
    text: holding != null
        ? holding.quantity.toStringAsFixed(4)
        : '',
  );
  final TextEditingController costController = TextEditingController(
    text: holding != null
        ? Money.fromMinor(holding.avgCostMinor).decimal.toStringAsFixed(4)
        : '',
  );
  final TextEditingController priceController = TextEditingController(
    text: holding != null
        ? Money.fromMinor(holding.currentPriceMinor).decimal.toStringAsFixed(4)
        : '',
  );
  final TextEditingController noteController =
      TextEditingController(text: holding?.note ?? '');

  InvestmentType type = holding?.type ?? InvestmentType.fund;

  final bool? saved = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialog) => StatefulBuilder(
      builder: (BuildContext ctx, StateSetter setState) => AlertDialog(
        title: Text(holding == null ? '新增持仓' : '编辑持仓'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: symbolController,
                decoration: const InputDecoration(labelText: '代码（如 110022）'),
                autofocus: true,
              ),
              const FormGap(),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '名称'),
              ),
              const FormGap(),
              EnumDropdown<InvestmentType>(
                label: '品种',
                value: type,
                values: InvestmentType.values,
                labelOf: (InvestmentType t) => t.label,
                onChanged: (InvestmentType t) => setState(() => type = t),
              ),
              const FormGap(),
              IntField(
                controller: quantityController,
                label: '份额',
                helperText: '支持 4 位小数，内部放大 1e6 存整数',
              ),
              const FormGap(),
              TextField(
                controller: costController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '成本单价',
                  prefixText: '¥ ',
                ),
              ),
              const FormGap(),
              TextField(
                controller: priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '当前单价',
                  prefixText: '¥ ',
                  helperText: '留空则默认等于成本单价',
                ),
              ),
              const FormGap(),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: '备注'),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('保存'),
          ),
        ],
      ),
    ),
  );

  if (saved != true || !context.mounted) return;

  final double? quantity = double.tryParse(quantityController.text.trim());
  final double? cost = double.tryParse(costController.text.trim());
  final double? price = double.tryParse(priceController.text.trim());
  if (quantity == null || quantity <= 0) {
    showToast(context, '份额必须大于 0');
    return;
  }
  if (cost == null || cost < 0) {
    showToast(context, '成本单价不合法');
    return;
  }

  final int quantityMicros =
      (quantity * InvestmentRepository.quantityScale).round();
  final int costMinor = Money.fromDecimal(cost).minor;
  final int priceMinor =
      price == null ? costMinor : Money.fromDecimal(price).minor;
  final String note = noteController.text.trim();

  final InvestmentRepository repo = ref.read(investmentRepositoryProvider);
  try {
    if (holding == null) {
      await repo.add(
        bookId: ref.read(currentBookIdProvider),
        symbol: symbolController.text,
        name: nameController.text,
        type: type,
        quantityMicros: quantityMicros,
        avgCostMinor: costMinor,
        currentPriceMinor: priceMinor,
        note: note.isEmpty ? null : note,
      );
    } else {
      await repo.update(
        id: holding.id,
        symbol: symbolController.text,
        name: nameController.text,
        type: type,
        quantityMicros: quantityMicros,
        avgCostMinor: costMinor,
        currentPriceMinor: priceMinor,
        accountId: holding.accountId,
        note: note.isEmpty ? null : note,
      );
    }
  } on AppFailure catch (e) {
    if (context.mounted) showToast(context, e.message);
  }
}
