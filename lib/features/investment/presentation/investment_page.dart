import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/form_fields.dart';
import '../../../shared/widgets/amount_keypad.dart';
import '../../../shared/widgets/module_list_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../ledger/presentation/widgets/txn_slidable.dart';
import '../data/investment_repository.dart';
import '../providers/investment_providers.dart';
import 'holding_detail_page.dart';
import '../../../theme/theme.dart';

/// 投资页：顶部组合汇总卡 + 持仓 / 清仓双 Tab（对齐分期入口布局）。
///
/// 下方为卡片列表：持仓 Tab 显份额 > 0 的标的，清仓 Tab 显已卖光
/// （份额 = 0，保留历史）的标的。现价支持免费第三方行情自动更新
/// （一期：基金天天基金 + 加密货币 Binance），无网络 / 失败时保留旧价；
/// 也可在持仓详情或新建表单手动录入，配合 [InvestmentRepository.updatePrice]。
class InvestmentPage extends ConsumerStatefulWidget {
  const InvestmentPage({super.key});

  @override
  ConsumerState<InvestmentPage> createState() => _InvestmentPageState();
}

class _InvestmentPageState extends ConsumerState<InvestmentPage> {
  bool _showCleared = false;
  bool _refreshing = false;

  Future<void> _refreshPrices() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await ref.read(refreshPricesProvider.future);
    } catch (_) {
      // 离线/限流：保留旧价。
    } finally {
      if (mounted) {
        ref.invalidate(investmentListProvider);
        setState(() => _refreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<InvestmentHolding>> holdings =
        ref.watch(investmentListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('投资'),
        actions: <Widget>[
          IconButton(
            icon: _refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: '刷新行情',
            onPressed: _refreshing ? null : _refreshPrices,
          ),
        ],
      ),
      body: holdings.when(
        data: (List<InvestmentHolding> list) {
          // 清仓 = 份额归 0（卖出后保留记录便于回看历史）。
          final List<InvestmentHolding> filtered = list
              .where((InvestmentHolding h) =>
                  (h.quantityMicros == 0) == _showCleared)
              .toList(growable: false);
          return Column(
            children: <Widget>[
              const _PortfolioSummaryCard(),
              _buildSegmented(),
              Expanded(
                child: filtered.isEmpty
                    ? EmptyState(
                        icon: _showCleared
                            ? Icons.history_outlined
                            : Icons.show_chart,
                        message: _showCleared
                            ? '暂无清仓记录'
                            : '还没有持仓，点右下角「+」新增',
                      )
                    : TxnSlidableGroup(
                        child: ListView.separated(
                          padding: const EdgeInsets.only(top: 4, bottom: 88),
                          itemCount: filtered.length,
                          separatorBuilder: (BuildContext _, int __) =>
                              const Divider(height: 1),
                          itemBuilder: (BuildContext context, int index) {
                            final InvestmentHolding h = filtered[index];
                            return Slidable(
                              key: ValueKey<String>('holding-slidable-${h.id}'),
                              // 与流水行共用互斥组：打开新行时旧行自动滑回。
                              groupTag: TxnSlidable.groupTag,
                              endActionPane: ActionPane(
                                motion: const DrawerMotion(),
                                extentRatio: 0.32,
                                children: <Widget>[
                                  TxnSlideAction(
                                    icon: Icons.edit_outlined,
                                    semanticLabel: '编辑',
                                    color: AppPalette.info,
                                    onPressed: () =>
                                        showHoldingEditor(context, ref, h),
                                  ),
                                  TxnSlideAction(
                                    icon: Icons.delete_outline,
                                    semanticLabel: '删除',
                                    color: AppPalette.danger,
                                    onPressed: () =>
                                        _confirmDelete(context, ref, h),
                                  ),
                                ],
                              ),
                              child: _HoldingCard(
                                holding: h,
                                cleared: _showCleared,
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => Center(child: Text('加载失败：$e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showHoldingEditor(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  // ---------------------------------------------------------------- 视图

  /// 左滑删除持仓：软删持仓 + 级联删名下全部买卖流水（余额同步冲回），不可撤销。
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    InvestmentHolding h,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('删除持仓'),
        content: Text('删除「${h.symbol} ${h.name}」后不再显示，'
            '名下买卖流水将一并删除，资金账户余额同步冲回，此操作不可撤销。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              '删除',
              style: TextStyle(color: AppPalette.danger),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      await ref.read(investmentRepositoryProvider).remove(h.id);
      if (context.mounted) showToast(context, '已删除');
    } on AppFailure catch (e) {
      if (context.mounted) showToast(context, e.message);
    }
  }

  Widget _buildSegmented() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppPalette.sage50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Expanded(child: _buildSegmentItem('持仓', !_showCleared)),
          Expanded(child: _buildSegmentItem('清仓', _showCleared)),
        ],
      ),
    );
  }

  Widget _buildSegmentItem(String label, bool selected) {
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: () {
        if (!selected) setState(() => _showCleared = label == '清仓');
      },
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.surface
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: AppPalette.textPrimary.withValues(alpha: 0.08),
                    blurRadius: 3,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? AppPalette.sage700 : AppPalette.textSecondary,
          ),
        ),
      ),
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
    final bool isDark = theme.brightness == Brightness.dark;
    final Color profitColor = summary.profitMinor > 0
        ? AppPalette.stock(true, dark: isDark)
        : summary.profitMinor < 0
            ? AppPalette.stock(false, dark: isDark)
            : theme.textTheme.bodyMedium?.color ?? theme.colorScheme.onSurfaceVariant;

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 注意：headlineSmall 未在 AppTextStyles 中定义、不会经主题
            // .apply(onSurface) 着色，默认色在浅色卡上近乎不可见——
            // 市值主数字必须显式指定 textPrimary（下同，全页显式补色）。
            Text(
              '持仓市值',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppPalette.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              Money.fromMinor(summary.marketValueMinor).format(),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: AppPalette.textPrimary,
              ),
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
                    value: '${(summary.profitRatio * 100).toStringAsFixed(2)}%',
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
        Text(
          label,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: AppPalette.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: color ?? AppPalette.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// 单个持仓卡片（对齐分期卡片布局）：品种徽章 + 代码/名称 / 成本现价副行 /
/// 持仓市值 + 浮动盈亏。点击进持仓详情页（含交易流水），长按快捷改现价。
class _HoldingCard extends ConsumerWidget {
  const _HoldingCard({required this.holding, this.cleared = false});

  final InvestmentHolding holding;

  /// 是否清仓记录（份额 = 0）：徽章显「已清仓」，市值/盈亏为 0。
  final bool cleared;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final TextTheme t = theme.textTheme;
    final int profit = holding.profitMinor;
    final bool isDark = theme.brightness == Brightness.dark;
    final Color profitColor = profit > 0
        ? AppPalette.stock(true, dark: isDark)
        : profit < 0
            ? AppPalette.stock(false, dark: isDark)
            : AppPalette.textSecondary;

    final String? updatedLabel = holding.priceUpdatedAt == null
        ? null
        : DateFormat('MM-dd HH:mm').format(
            DateTime.fromMillisecondsSinceEpoch(
              holding.priceUpdatedAt!,
              isUtc: true,
            ).toLocal(),
          );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppPalette.hairline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext _) => HoldingDetailPage(holdingId: holding.id),
          ),
        ),
        onLongPress: () => _showPriceEditor(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  _badge(
                    cleared
                        ? '已清仓'
                        : investmentTypeLabel(
                            holding.type,
                            holding.symbol,
                            name: holding.name,
                            all: ref.watch(investmentListProvider).valueOrNull,
                          ),
                    cleared ? AppPalette.textTertiary : AppPalette.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${holding.symbol}  ${holding.name}',
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
              const SizedBox(height: 4),
              Text(
                <String>[
                  '${holding.quantity.toStringAsFixed(4)} 份',
                  '成本 ${Money.fromMinor(holding.avgCostMinor).format()}',
                  '现价 ${Money.fromMinor(holding.currentPriceMinor).format()}',
                  if (updatedLabel != null) updatedLabel,
                ].join(' · '),
                style: t.bodySmall?.copyWith(color: AppPalette.textSecondary),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '持仓市值',
                        style:
                            t.bodySmall?.copyWith(color: AppPalette.textSecondary),
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
                        style:
                            t.bodySmall?.copyWith(color: AppPalette.textSecondary),
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
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Future<void> _showPriceEditor(BuildContext context, WidgetRef ref) async {
    final TextEditingController controller = TextEditingController(
      text:
          Money.fromMinor(holding.currentPriceMinor).decimal.toStringAsFixed(4),
    );
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialog) => AlertDialog(
        title: Text('更新 ${holding.symbol} 现价'),
        content: KeypadField(
          controller: controller,
          allowDecimal: true,
          maxDecimalDigits: 4,
          title: '更新现价',
          decoration: const InputDecoration(
            labelText: '现价',
            prefixText: '¥ ',
            helperText: '支持 4 位小数，用于基金净值',
          ),
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

  InvestmentType type = holding?.type ?? InvestmentType.fund;

  // 底部弹窗（与全应用弹层统一：圆角 24 + 拖拽条 + 键盘避让）。
  // 只维护标的元信息：代码 / 名称 / 品种；份额、成本、现价一律由
  // 记账表单的买卖交易驱动（编辑时原值透传，不动账）。
  final bool? saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheet) => StatefulBuilder(
      builder: (BuildContext ctx, StateSetter setState) => Padding(
        // 键盘避让：输入框唤起系统键盘时弹层整体升到键盘上方。
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: AppPalette.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // 拖拽条
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(top: 10, bottom: 6),
                      decoration: BoxDecoration(
                        color: AppPalette.hairline,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  // 标题行：编辑持仓 / 新增持仓 + 关闭
                  Row(
                    children: <Widget>[
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, size: 22),
                        color: AppPalette.textTertiary,
                        onPressed: () => Navigator.of(ctx).pop(false),
                      ),
                    ],
                  ),
                  Text(
                    holding == null ? '新增持仓' : '编辑持仓',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
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
                    values: InvestmentType.displayOrder,
                    labelOf: (InvestmentType t) => t.label,
                    onChanged: (InvestmentType t) => setState(() => type = t),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('保存'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  if (saved != true || !context.mounted) return;

  final InvestmentRepository repo = ref.read(investmentRepositoryProvider);
  try {
    if (holding == null) {
      // 新建 = 零仓观察标的：份额/成本为 0，后续由买卖交易建仓。
      await repo.add(
        bookId: ref.read(currentBookIdProvider),
        symbol: symbolController.text,
        name: nameController.text,
        type: type,
        quantityMicros: 0,
        avgCostMinor: 0,
        currentPriceMinor: 0,
      );
    } else {
      // 编辑 = 只改元信息；数量/成本/现价/备注原值透传（账务由交易驱动）。
      await repo.update(
        id: holding.id,
        symbol: symbolController.text,
        name: nameController.text,
        type: type,
        quantityMicros: holding.quantityMicros,
        avgCostMinor: holding.avgCostMinor,
        currentPriceMinor: holding.currentPriceMinor,
        accountId: holding.accountId,
        note: holding.note,
      );
    }
  } on AppFailure catch (e) {
    if (context.mounted) showToast(context, e.message);
  }
}
