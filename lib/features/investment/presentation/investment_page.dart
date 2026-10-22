import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:pocket_ledger/shared/widgets/confirm_dialog.dart';
import 'package:pocket_ledger/shared/widgets/form_dialog.dart';
import 'package:pocket_ledger/shared/widgets/hairline_card.dart';
import 'package:pocket_ledger/shared/widgets/loading_state.dart';
import 'package:pocket_ledger/shared/widgets/sheet_scaffold.dart';

import '../../../core/errors/failures.dart';
import '../../../core/theme/forest_design_tokens.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/amount_keypad.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/form_fields.dart';
import '../../../shared/widgets/line_icon_map.dart';
import '../../../shared/widgets/module_list_scaffold.dart';
import '../../../theme/theme.dart';
import '../../ledger/presentation/widgets/txn_slidable.dart';
import '../data/investment_repository.dart';
import '../data/market/security_meta_repository.dart';
import '../providers/investment_providers.dart';
import 'holding_detail_page.dart';
import 'widgets/security_candidate_tile.dart';

/// 投资页：顶部组合汇总卡 + 持仓 / 清仓双 Tab（对齐分期入口布局）。
///
/// 下方为卡片列表：持仓 Tab 显份额 > 0 的标的，清仓 Tab 显已卖光
/// （份额 = 0，保留历史）的标的。现价支持免费第三方行情自动更新
/// （一期：基金天天基金 + 加密货币 Binance），无网络 / 失败时保留旧价；
/// 也可在持仓详情或新建表单手动录入，配合 [InvestmentRepository.updatePrice]。
///
/// 新增入口（第 47 批，真机反馈）：右上角「+」移除，收敛到底部
/// 「+ 记一笔投资」深绿渐变胶囊——与分期 / 退款 / 借还 / 报销各模块
/// 底栏主按钮口径一致；空态标语同步指向下方按钮。
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
    int updated = -1;
    try {
      // 手动刷新绕过「每天一次」节流（force）：既尊重用户主动意图，
      // 也在行情解析出错修正后能立即重取正确价。
      updated = await ref
          .read(investmentRepositoryProvider)
          .refreshAllPrices(force: true);
    } catch (_) {
      // 离线/限流：保留旧价。
    } finally {
      if (mounted) {
        ref.invalidate(investmentListProvider);
        setState(() => _refreshing = false);
        // 结果反馈：源失败静默跳过时用户只会觉得「点了没反应」，
        // 必须明示更新了几只 / 是否整体失败（2026-10-14 真机反馈）。
        if (updated < 0) {
          showAppToast(context, '刷新失败，请检查网络后重试');
        } else if (updated == 0) {
          showAppToast(context, '行情源暂不可用，已保留现价');
        } else {
          showAppToast(context, '已更新 $updated 只现价');
        }
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
        // 第 47 批：右上角「+」移除，新增入口收敛到底部「+ 记一笔投资」
        // 胶囊（与分期 / 退款 / 借还 / 报销底栏主按钮口径一致）；
        // 顶部只保留刷新行情。
        actions: <Widget>[
          IconButton(
            icon: _refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const LineGlyph(Icons.refresh),
            tooltip: '刷新行情',
            onPressed: _refreshing ? null : _refreshPrices,
          ),
        ],
      ),
      body: holdings.when(
        data: (List<InvestmentHolding> list) {
          // 轮次划分：清仓后再买入会开新一轮——持仓卡只看当前轮，
          // 清仓卡累计历史；当前持仓若含历史已完成轮，清仓 Tab 额外给一张历史卡。
          final Map<String, HoldingCycleInfo> cyc =
              ref.watch(investmentCycleInfoProvider).valueOrNull ??
                  const <String, HoldingCycleInfo>{};
          // 清仓 Tab：份额为 0 的清仓卡，或「当前持仓但含历史轮」的历史清仓卡。
          // 持仓 Tab：仅份额 > 0 的当前轮卡片。
          final List<InvestmentHolding> filtered = list
              .where(
                (InvestmentHolding h) => _showCleared
                    ? (h.quantityMicros == 0 ||
                        (cyc[h.id]?.hasHistory ?? false))
                    : h.quantityMicros > 0,
              )
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
                        // 第 47 批：新增入口移到底部胶囊，标语同步改指下方
                        // （与分期 / 退款空态口径一致）。
                        message: _showCleared
                            ? '暂无清仓记录'
                            : '还没有持仓，点下方「+ 记一笔投资」新增',
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
                                cycleInfo: cyc[h.id],
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
        loading: () => const LoadingState(),
        error: (Object e, StackTrace _) => Center(child: Text('加载失败：$e')),
      ),
      // 第 47 批：新增入口从右上角「+」收敛到底部主操作条。
      bottomNavigationBar: _bottomBar(context),
    );
  }

  // ---------------------------------------------------------------- 视图

  /// 底部主操作条：第 47 批从右上角「+」收敛到此处，与分期 / 退款 / 借还 /
  /// 报销底栏口径一致——单个深绿渐变胶囊「+ 记一笔投资」（图标 + 文案），
  /// 点开新建持仓表单（投资无「记一笔」Tab，仍走本页编辑器）。
  Widget _bottomBar(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Container(
        color: scheme.surface,
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
        child: SizedBox(
          width: double.infinity,
          height: 46,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => showHoldingEditor(context, ref),
            child: Container(
              decoration: BoxDecoration(
                gradient: ForestGradients.button,
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  LineGlyph(
                    Icons.add,
                    size: 18,
                    color: scheme.onPrimary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '记一笔投资',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: scheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 左滑删除持仓：软删持仓 + 级联删名下全部买卖流水（余额同步冲回），不可撤销。
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    InvestmentHolding h,
  ) async {
    final bool? confirm = await showConfirm(
      context,
      title: '删除持仓',
      content: '删除「${h.name} ${h.symbol}」后不再显示，'
          '名下买卖流水将一并删除，资金账户余额同步冲回，此操作不可撤销。',
      confirmText: '删除',
      danger: true,
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
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.08),
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
            color: selected
                ? AppPalette.sage700
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// 组合汇总卡片：总资产（现金+市值）/ 持仓市值·现金·仓位 / 摊薄总成本 / 总盈亏。
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
            : theme.textTheme.bodyMedium?.color ??
                theme.colorScheme.onSurfaceVariant;

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 注意：headlineSmall 未在 AppTextStyles 中定义、不会经主题
            // .apply(onSurface) 着色，默认色在浅色卡上近乎不可见——
            // 主数字必须显式指定 textPrimary（下同，全页显式补色）。
            Text(
              '总资产',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              Money.fromMinor(summary.totalAssetMinor).format(),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _Metric(
                    label: '持仓市值',
                    value: Money.fromMinor(summary.marketValueMinor).format(),
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: '现金',
                    value: Money.fromMinor(summary.cashMinor).format(),
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: '仓位',
                    value:
                        '${(summary.positionRatio * 100).toStringAsFixed(2)}%',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
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
                    label: '总盈亏',
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
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: color ?? Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// 日期格式化（yyyy-MM-dd；null 显「—」），供历史卡日期行使用。
String _fmtYmd(DateTime? d) {
  if (d == null) return '—';
  final String mm = d.month.toString().padLeft(2, '0');
  final String dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd';
}

/// 单个持仓卡片（对齐分期卡片布局）：品种徽章 + 代码/名称 / 成本现价副行 /
/// 持仓市值 + 总盈亏。点击进持仓详情页（含交易流水），长按快捷改现价。
class _HoldingCard extends ConsumerWidget {
  const _HoldingCard({
    required this.holding,
    this.cleared = false,
    this.cycleInfo,
  });

  final InvestmentHolding holding;

  /// 是否清仓记录（份额 = 0，或当前持仓但展示历史清仓）：徽章显「已清仓/历史清仓」。
  final bool cleared;

  /// 轮次划分（持仓/清仓双卡展示与口径的数据源）；null 时回退行级摊薄口径。
  final HoldingCycleInfo? cycleInfo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final TextTheme t = theme.textTheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final HoldingCycleInfo? info = cycleInfo;

    // 按轮次口径计算展示值：清仓/历史卡累计历史，持仓卡只看当前轮（不计历史）。
    int qtyMicros = holding.quantityMicros;
    int marketMinor = holding.marketValueMinor;
    int costAvgMinor;
    int profitMinor;
    String costLabel;
    String badgeLabel;
    Color badgeColor;

    // 历史卡字段（清仓/历史清仓共用）：累计投入=累计买入净额、总盈亏=历史清仓金额。
    int histRealized = 0;
    int histInvested = 0;
    int histAvgCost = 0; // 清仓后单价成本 = 累计投入 ÷ 累计买入份额
    double histRatio = 0;
    int histDays = -1; // -1 = 未知（无已完成轮）
    DateTime? histFirstBuy;
    DateTime? histLastSell;

    if (cleared) {
      // 历史卡：累计已完成轮（可能多轮）。不显份额/持仓市值。
      final List<HoldCycle> rounds = info?.completed ?? const <HoldCycle>[];
      histRealized = info?.historyRealizedMinor ?? holding.realizedProfitMinor;
      histInvested = info?.historyInvestedMinor ?? 0;
      histAvgCost = info?.historyAvgCostMinor ?? 0;
      histRatio = histInvested == 0 ? 0.0 : histRealized / histInvested;
      if (rounds.isNotEmpty) {
        histFirstBuy = rounds.first.startedAt;
        histLastSell = rounds.last.endedAt;
        if (histLastSell != null) {
          // 历史持仓天数 = 首次买入 → 最近卖出（清仓时点）。
          histDays = histLastSell.difference(histFirstBuy).inDays.abs();
        }
      }
      costAvgMinor = histInvested; // 清仓路径不消费（仅保证 definite assignment）
      profitMinor = histRealized; // 总盈亏 = 历史清仓金额
      costLabel = '成本';
      badgeLabel = holding.quantityMicros == 0 ? '已清仓' : '历史清仓';
      badgeColor = Theme.of(context).colorScheme.onSurfaceVariant;
    } else if (info != null &&
        info.open != null &&
        holding.quantityMicros > 0) {
      // 当前轮（不计历史）：成本/盈亏只看这一轮。
      final HoldCycle open = info.open!;
      final int dilutedCost = open.dilutedCostValueMinor;
      costAvgMinor = open.dilutedAvgCostMinor;
      profitMinor = marketMinor - dilutedCost;
      costLabel = '成本单价';
      badgeLabel = investmentTypeLabel(
        holding.type,
        holding.symbol,
        name: holding.name,
        all: ref.watch(investmentListProvider).valueOrNull,
      );
      badgeColor = AppPalette.primary;
    } else {
      // 兜底（无流水解析）：沿用行级摊薄口径。
      costAvgMinor = holding.dilutedAvgCostMinor;
      profitMinor = holding.dilutedProfitMinor;
      costLabel = '成本单价';
      badgeLabel = investmentTypeLabel(
        holding.type,
        holding.symbol,
        name: holding.name,
        all: ref.watch(investmentListProvider).valueOrNull,
      );
      badgeColor = AppPalette.primary;
    }

    final Color profitColor = profitMinor > 0
        ? AppPalette.stock(true, dark: isDark)
        : profitMinor < 0
            ? AppPalette.stock(false, dark: isDark)
            : Theme.of(context).colorScheme.onSurfaceVariant;

    return HairlineCard(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext _) => HoldingDetailPage(
              holdingId: holding.id,
              // 清仓 Tab 下、份额仍 > 0 的卡 = 历史清仓卡，进入累计历史复盘视图。
              historyMode: cleared && holding.quantityMicros > 0,
            ),
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
                  _badge(badgeLabel, badgeColor),
                  const SizedBox(width: 8),
                  Expanded(
                    // 名称在前（主字号），代码在后（小一号、次级色）。
                    child: Row(
                      children: <Widget>[
                        Flexible(
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
                        const SizedBox(width: 6),
                        Text(
                          holding.symbol,
                          style: t.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (cleared) ...<Widget>[
                // 历史卡：不显份额/持仓市值。大字对 = 累计投入 | 总盈亏(历史清仓)。
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '累计投入',
                          style: t.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          Money.fromMinor(histInvested).format(),
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
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          Money.fromMinor(histRealized).formatSigned(),
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
                // 指标行：成本(清仓单价) | 收益 | 现价。
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _histMetric(
                        context,
                        t,
                        '成本',
                        histAvgCost == 0
                            ? '—'
                            : Money.fromMinor(histAvgCost).format(),
                      ),
                    ),
                    Expanded(
                      child: _histMetric(
                        context,
                        t,
                        '收益',
                        histInvested == 0
                            ? '—'
                            : '${(histRatio * 100).toStringAsFixed(2)}%',
                        color: profitColor,
                      ),
                    ),
                    Expanded(
                      child: _histMetric(
                        context,
                        t,
                        '现价',
                        Money.fromMinor(holding.currentPriceMinor).format(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 日期行：持仓天数 | 首次买入 | 最近卖出。
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _histMetric(
                        context,
                        t,
                        '持仓天数',
                        histDays < 0 ? '—' : '$histDays 天',
                      ),
                    ),
                    Expanded(
                      child: _histMetric(
                        context,
                        t,
                        '首次买入',
                        _fmtYmd(histFirstBuy),
                      ),
                    ),
                    Expanded(
                      child: _histMetric(
                        context,
                        t,
                        '最近卖出',
                        _fmtYmd(histLastSell),
                      ),
                    ),
                  ],
                ),
              ] else ...<Widget>[
                // 持仓卡：副行只显份额 / 成本 / 现价；买卖日期与行情更新时间
                // 不进卡片（详情页「首次买入 / 最近卖出」行可见）。
                Text(
                  <String>[
                    '份额 ${formatQuantity(qtyMicros / InvestmentRepository.quantityScale)}',
                    '$costLabel ${Money.fromMinor(costAvgMinor).format()}',
                    '现价 ${Money.fromMinor(holding.currentPriceMinor).format()}',
                  ].join(' · '),
                  style: t.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
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
                          style: t.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          Money.fromMinor(marketMinor).format(),
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
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
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
              ],
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

  /// 历史卡指标项：标签在上（次级色）、值在下（加粗）。
  Widget _histMetric(
    BuildContext context,
    TextTheme t,
    String label,
    String value, {
    Color? color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: t.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
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

  Future<void> _showPriceEditor(BuildContext context, WidgetRef ref) async {
    final TextEditingController controller = TextEditingController(
      text:
          Money.fromMinor(holding.currentPriceMinor).decimal.toStringAsFixed(4),
    );
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext _) => FormDialog(
        title: '更新 ${holding.symbol} 现价',
        confirmText: '更新',
        body: KeypadField(
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

/// 候选库后台加载防重入集合（按品种）。
final Set<InvestmentType> _holdingMetaLoading = <InvestmentType>{};

/// 触发某品种候选库后台加载（首拉/每周），完成后刷新补全 provider。
/// 全部 9 个品种均已接候选库（fund/crypto/stock/bond/metal/forex/futures/option/other），
/// 走 [MarketService.ensureCandidates]，内部对未覆盖品种空返回，故此处不再按品种过滤。
void _ensureMetaLoaded(WidgetRef ref, InvestmentType type) {
  if (_holdingMetaLoading.contains(type)) return;
  _holdingMetaLoading.add(type);
  final Future<void> _ = ref
      .read(marketServiceProvider)
      .ensureCandidates(type)
      .then((_) => ref.invalidate(securityMetaSearchProvider))
      .catchError((Object _) {
    // 忽略：候选库为空时仅手输可用。
  }).whenComplete(() => _holdingMetaLoading.remove(type));
}

/// 新建持仓代码框按品种给示例提示。
String _symbolHint(InvestmentType type) {
  switch (type) {
    case InvestmentType.stock:
      return '如 600000 / 600000.SH / AAPL';
    case InvestmentType.fund:
      return '如 110022';
    case InvestmentType.crypto:
      return '如 BTCUSDT';
    case InvestmentType.forex:
      return '如 USD/CNY';
    case InvestmentType.bond:
      return '如 019742.SH';
    case InvestmentType.metal:
      return '如 XAU / 119.XAU';
    case InvestmentType.futures:
      return '如 AG2501（自动识别 114.AG2501）';
    case InvestmentType.option:
      return '如 CU2501C70000（自动识别 114.…）';
    case InvestmentType.other:
      return '如 LC2501（非标品种，自动识别 114.…）';
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
  final bool? saved = await showAppModalSheet<bool>(
    context,
    isScrollControlled: true,
    surfaceColor: AppPalette.white,
    body: StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // 标题行：编辑持仓 / 新增持仓 + 关闭
              Row(
                children: <Widget>[
                  const Spacer(),
                  IconButton(
                    icon: const LineGlyph(Icons.close, size: 22),
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              Text(
                holding == null ? '新增持仓' : '编辑持仓',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: symbolController,
                decoration: InputDecoration(
                  labelText: '代码 / 标的',
                  hintText: _symbolHint(type),
                ),
                autofocus: true,
                onChanged: (_) => setState(() {}),
              ),
              const FormGap(),
              Consumer(
                builder: (BuildContext context, WidgetRef ref, _) {
                  final String q = symbolController.text.trim();
                  if (q.isEmpty) return const SizedBox.shrink();
                  _ensureMetaLoaded(ref, type);
                  final AsyncValue<List<SecurityCandidate>> meta = ref.watch(
                    securityMetaSearchProvider(MetaQuery(q, type)),
                  );
                  return meta.when(
                    data: (List<SecurityCandidate> cands) {
                      if (cands.isEmpty) return const SizedBox.shrink();
                      return HairlineCard(
                        radius: 12,
                        margin: const EdgeInsets.only(top: 6),
                        padding: EdgeInsets.zero,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            for (final SecurityCandidate c in cands)
                              SecurityCandidateTile(
                                candidate: c,
                                onTap: () {
                                  symbolController.text = c.symbol;
                                  if (nameController.text.isEmpty) {
                                    nameController.text = c.name;
                                  }
                                  setState(() {});
                                  FocusManager.instance.primaryFocus?.unfocus();
                                },
                              ),
                          ],
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (Object _, StackTrace? __) =>
                        const SizedBox.shrink(),
                  );
                },
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
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('保存'),
              ),
            ],
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
