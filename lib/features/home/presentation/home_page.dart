import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocket_ledger/shared/widgets/loading_state.dart';

import 'package:pocket_ledger/theme/app_dimens.dart';
import '../../../core/theme/forest_asset_design_tokens.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../routing/app_router.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/animated_money_text.dart';
import '../../../shared/widgets/day_group_header.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/widgets/line_icon_map.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../theme/app_colors.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../../budget/providers/budget_providers.dart';
import '../../ledger/presentation/transaction_detail_sheet.dart';
import '../../ledger/presentation/widgets/transaction_tile.dart';
import '../../ledger/presentation/widgets/txn_slidable.dart';
import '../../ledger/providers/ledger_providers.dart';
import '../../lend/providers/lend_providers.dart';
import '../../record/presentation/record_sheet.dart';

/// 首页总览：顶部四张可横向滑动卡片（支出预算 / 收入目标 / 本月收支 / 资产）
/// + 快捷入口 + 最近流水。
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Transaction>> recent =
        ref.watch(recentTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('首页'),
        actions: <Widget>[
          IconButton(
            icon: const LineGlyph(Icons.settings_outlined),
            onPressed: () => context.push(Routes.settings),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(syncControllerProvider.notifier).syncNow(),
        child: ListView(
          padding: const EdgeInsets.all(AppDimens.lg),
          children: <Widget>[
            const FadeSlideIn(child: _SwipeCards()),
            const SizedBox(height: AppDimens.lg),
            const FadeSlideIn(
              delay: Duration(milliseconds: 90),
              child: _QuickActions(),
            ),
            const SizedBox(height: AppDimens.xxl),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                const Expanded(
                  child: SectionHeader(title: '最近流水'),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12, top: 12),
                  child: TextButton(
                    onPressed: () => context.go(Routes.ledger),
                    child: const Text('查看全部'),
                  ),
                ),
              ],
            ),
            recent.when(
              data: (List<Transaction> list) {
                if (list.isEmpty) {
                  return const SizedBox(
                    height: 180,
                    child: EmptyState(message: '还没有记账记录，点下方按钮记一笔'),
                  );
                }
                // 按自然日分组（对齐账单明细页样式）：每组前插「M月d日
                // （今天/昨天）… N笔」日头，N = 可见 5 条里该日的笔数。
                final List<Transaction> visible =
                    list.take(5).toList(growable: false);
                final List<Widget> rows = <Widget>[];
                for (int i = 0; i < visible.length; i++) {
                  final Transaction txn = visible[i];
                  final bool showHeader = i == 0 ||
                      !DayGroupHeader.sameDay(
                        visible[i - 1].occurredAt,
                        txn.occurredAt,
                      );
                  if (showHeader) {
                    int count = 1;
                    while (i + count < visible.length &&
                        DayGroupHeader.sameDay(
                          visible[i].occurredAt,
                          visible[i + count].occurredAt,
                        )) {
                      count++;
                    }
                    rows.add(
                      DayGroupHeader(
                        date: DayGroupHeader.localDay(txn.occurredAt),
                        count: count,
                        // 首页 ListView 自带水平 padding，去掉组件默认水平边距。
                        padding: const EdgeInsets.only(
                          top: AppDimens.xs,
                          bottom: AppDimens.xs,
                        ),
                      ),
                    );
                  }
                  rows.add(
                    TxnSlidable(
                      txn: txn,
                      child: TransactionTile(
                        transaction: txn,
                        onTap: () =>
                            TransactionDetailSheet.show(context, txn),
                      ),
                    ),
                  );
                }
                return TxnSlidableGroup(
                  child: Column(children: rows),
                );
              },
              loading: () => const SizedBox(
                height: 120,
                child: LoadingState(),
              ),
              error: (Object e, StackTrace? s) => SizedBox(
                height: 120,
                child: Center(child: Text('加载失败：$e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 顶部四张横向卡片：本月支出预算 / 本月收入目标 / 本月收支 / 资产总览。
///
/// 用 [PageView] 让用户左右滑动浏览；下面接 [_PageDots] 指示当前页。
/// 把 PageController 放在 StatefulWidget 里，否则 setState 不会触发指示点更新。
///
/// 第 32 批：原三张卡（预算/收支/资产）的预算卡把全部预算行不分月/年、
/// 不分支出/收入累计求和（10 月支出 10,000 + 年收入目标 1,000 = 11,000），
/// 且收入方向无处展示。现拆为「支出预算 / 收入目标」两张卡，数据走
/// [monthBudgetSummaryProvider] 按方向取**当月月度**预算（与预算主页
/// 「N月预算」月视图同口径）；年/季度预算在预算页年视图查看。
///
/// 第 33 批：四张卡**双向循环**。早期用「头尾复制 + 滑到副本瞬间 jumpToPage
/// 跳回」实现，但松手那一下会被瞬移打断、没有惯性滑行，循环到首尾时很生硬。
/// 现改 **`PageView.builder` 无限列表**方案：`itemCount: null` 让左右两边都
/// 永远有真实页可滑，不需要任何「跳回」逻辑，循环时惯性连续、绝不卡顿；
/// `itemBuilder` 里用 `index % 4` 循环复用四张真实卡，`initialPage` 取极远且
/// ≡ 2 (mod 4) 的下标默认停在「本月收支」卡。指示点直接用
/// `controller.page % count` 取环形位置（Dart 取模恒非负）。
class _SwipeCards extends ConsumerStatefulWidget {
  const _SwipeCards();

  @override
  ConsumerState<_SwipeCards> createState() => _SwipeCardsState();
}

class _SwipeCardsState extends ConsumerState<_SwipeCards> {
  static const double _cardHeight = 184;

  /// 真实卡片数（指示点数）。children 即四张真实卡，不做头尾复制。
  static const int _pageCount = 4;

  /// 极大初始页码（且 ≡ 2 mod 4，落在「本月收支」卡），实现看似无限的双向
  /// 循环——日常滑动触不到真实边界，因此没有「瞬移跳回」的生硬感。
  static const int _initialPage = 100002; // 100002 % 4 == 2 → 本月收支卡

  // 默认停在「本月收支」卡（children 顺序：0 支出预算 / 1 收入目标 / 2 收支 / 3 资产）。
  final PageController _pageController = PageController(initialPage: _initialPage);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 三个卡的数据各自 ref.watch，StreamProvider 推数据时本 widget 自动重建，
    // 不再依赖外层 HomePage 重新挂载（修了"数据变化没反应"那一项）。
    final int netMinor = ref.watch(netAssetsProvider).valueOrNull ?? 0;
    final int assetsMinor = ref.watch(totalAssetsProvider).valueOrNull ?? 0;
    // 负债两个来源（避免口径漏算）：
    // ① 负债方向账户（信用卡/花呗等 debt + 私人借款 payable，含指定借入
    //    账户）正余额=欠款；
    // ② 借还模块**未指定账户**的借入未还净额（指定了借入账户的记录已在
    //    ①的账户余额里，provider 口径已排除，不会双计）。
    final int accountLiabilities =
        ref.watch(totalLiabilitiesProvider).valueOrNull ?? 0;
    final int borrowInOngoing =
        ref.watch(borrowInOngoingProvider).valueOrNull ?? 0;
    final int liabilitiesMinor = accountLiabilities + borrowInOngoing;
    // 第 32 批：预算模块按方向取当月月度预算（旧口径 Σ 全部行，月年累计）。
    final BudgetSummary expenseBudget =
        ref.watch(monthBudgetSummaryProvider(CategoryType.expense));
    final BudgetSummary incomeTarget =
        ref.watch(monthBudgetSummaryProvider(CategoryType.income));
    final int income = ref.watch(monthIncomeProvider).valueOrNull ?? 0;
    final int expense = ref.watch(monthExpenseProvider).valueOrNull ?? 0;

    return Column(
      children: <Widget>[
        SizedBox(
          height: _cardHeight,
          child: PageView.builder(
            controller: _pageController,
            // itemCount 为 null = 真正的无限列表：左右两边都永远有真实页可滑，
            // 不需要任何「跳回」逻辑，因此循环时惯性连续、没有瞬移卡顿。
            // initialPage 取极大且 100002 ≡ 2 (mod 4) → 默认停在「本月收支」卡。
            itemCount: null,
            itemBuilder: (BuildContext context, int index) {
              // 4 张真实卡按 (index % 4) 循环复用：0 支出预算 / 1 收入目标 /
              // 2 本月收支 / 3 资产总览。
              switch (index % _pageCount) {
                case 0:
                  return _BudgetCard(
                    summary: expenseBudget,
                    onTap: () => context.push(Routes.budget),
                  );
                case 1:
                  return _IncomeTargetCard(
                    summary: incomeTarget,
                    onTap: () => context.push(Routes.budget),
                  );
                case 2:
                  return _IncomeExpenseCard(
                    income: income,
                    expense: expense,
                    onTap: () => context.push(Routes.ledger),
                  );
                default:
                  return _AssetsCard(
                    totalAssets: assetsMinor,
                    totalLiabilities: liabilitiesMinor,
                    netAssets: netMinor - borrowInOngoing,
                    onTap: () => context.push(Routes.accounts),
                  );
              }
            },
          ),
        ),
        const SizedBox(height: AppDimens.sm),
        _PageDots(
          controller: _pageController,
          count: _pageCount,
        ),
      ],
    );
  }
}

/// 卡片4：资产总览（深绿底）。
class _AssetsCard extends StatelessWidget {
  const _AssetsCard({
    required this.totalAssets,
    required this.totalLiabilities,
    required this.netAssets,
    required this.onTap,
  });

  final int totalAssets;
  final int totalLiabilities;
  final int netAssets;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return _TappableSurface(
      onTap: onTap,
      background: ForestAssetBg.deep,
      gradient: ForestAssetBg.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '净资产',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: ForestAssetText.primary.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 2),
          AnimatedMoneyText(
            Money.fromMinor(netAssets),
            color: ForestAssetText.emphasis,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: ForestAssetText.emphasis,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Row(
            children: <Widget>[
              Expanded(
                child: _MiniStat(
                  label: '总资产',
                  valueMinor: totalAssets,
                  labelColor: ForestAssetText.primary.withValues(alpha: 0.85),
                  valueColor: ForestAssetText.emphasis,
                ),
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: _MiniStat(
                  label: '总负债',
                  valueMinor: totalLiabilities,
                  labelColor: ForestAssetText.primary.withValues(alpha: 0.85),
                  valueColor: ForestAssetText.emphasis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 卡片1：本月支出预算（森林绿渐变底）。
///
/// 第 32 批：数据改走 [monthBudgetSummaryProvider] 的支出方向——只统计
/// **当月月度**预算行（overall + 支出分类），与预算主页「N月预算」月视图
/// 同口径；旧卡 Σ 全部预算行（含年/季度、收入目标）导致月年累计。
class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.summary, required this.onTap});

  final BudgetSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool empty = summary.total == 0;
    return _TappableSurface(
      onTap: onTap,
      background: ForestAssetBg.deep,
      gradient: ForestAssetBg.card,
      child: empty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.lg,
                ),
                child: Text(
                  '本月未设置预算，点此去设置',
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(color: ForestAssetText.primary),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '剩余预算',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: ForestAssetText.primary.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedMoneyText(
                  Money.fromMinor(
                    summary.remaining >= 0 ? summary.remaining : 0,
                  ),
                  color: ForestAssetText.emphasis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: ForestAssetText.emphasis,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _MiniStat(
                        label: '总预算',
                        valueMinor: summary.total,
                        labelColor:
                            ForestAssetText.primary.withValues(alpha: 0.85),
                        valueColor: ForestAssetText.emphasis,
                      ),
                    ),
                    const SizedBox(width: AppDimens.md),
                    Expanded(
                      child: _MiniStat(
                        label: '已用',
                        valueMinor: summary.spent,
                        labelColor:
                            ForestAssetText.primary.withValues(alpha: 0.85),
                        valueColor: ForestAssetAccent.amberText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

/// 卡片2：本月收入目标（森林绿渐变底，第 32 批新增）。
///
/// 与卡片1（支出预算）对偶：大数字 = 还需收入（目标−已得）；超额达成时
/// 翻正显示「超额达成」。底部两枚统计 = 目标金额 / 已得。
/// 数据只取**当月月度**收入分类目标行（与预算主页「N月预算」月视图的
/// 「收入目标」同口径）——年收入目标（如 2026 年 ¥1,000）不在月度卡
/// 累计，在预算页年视图查看。
class _IncomeTargetCard extends StatelessWidget {
  const _IncomeTargetCard({required this.summary, required this.onTap});

  final BudgetSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool empty = summary.total == 0;
    // 收入方向「剩余」语义与支出相反：为负 = 超额达成（好事），翻正展示。
    final bool exceeded = summary.remaining < 0;
    final String bigLabel = exceeded ? '超额达成' : '还需收入';
    final int bigValue = exceeded ? -summary.remaining : summary.remaining;
    return _TappableSurface(
      onTap: onTap,
      background: ForestAssetBg.deep,
      gradient: ForestAssetBg.card,
      child: empty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.lg,
                ),
                child: Text(
                  '本月未设置收入目标，点此去设置',
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(color: ForestAssetText.primary),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  bigLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: ForestAssetText.primary.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedMoneyText(
                  Money.fromMinor(bigValue),
                  color: ForestAssetText.emphasis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: ForestAssetText.emphasis,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _MiniStat(
                        label: '目标金额',
                        valueMinor: summary.total,
                        labelColor:
                            ForestAssetText.primary.withValues(alpha: 0.85),
                        valueColor: ForestAssetText.emphasis,
                      ),
                    ),
                    const SizedBox(width: AppDimens.md),
                    Expanded(
                      child: _MiniStat(
                        label: '已得',
                        valueMinor: summary.spent,
                        labelColor:
                            ForestAssetText.primary.withValues(alpha: 0.85),
                        valueColor: ForestAssetSemantic.income,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

/// 卡片3：本月收支（森林绿渐变底）。
class _IncomeExpenseCard extends StatelessWidget {
  const _IncomeExpenseCard({
    required this.income,
    required this.expense,
    required this.onTap,
  });

  final int income;
  final int expense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int balance = income - expense;
    final Color balanceColor =
        balance >= 0 ? ForestAssetText.emphasis : ForestAssetSemantic.expense;
    return _TappableSurface(
      onTap: onTap,
      background: ForestAssetBg.deep,
      gradient: ForestAssetBg.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '本月结余',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: ForestAssetText.primary.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 2),
          AnimatedMoneyText(
            Money.fromMinor(balance),
            color: balanceColor,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: balanceColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Row(
            children: <Widget>[
              Expanded(
                child: _MiniStat(
                  label: '收入',
                  valueMinor: income,
                  labelColor: ForestAssetText.primary.withValues(alpha: 0.85),
                  valueColor: ForestAssetGreen.deep,
                ),
              ),
              const SizedBox(width: AppDimens.md),
              Expanded(
                child: _MiniStat(
                  label: '支出',
                  valueMinor: expense,
                  labelColor: ForestAssetText.primary.withValues(alpha: 0.85),
                  valueColor: ForestAssetSemantic.expense,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 可点击的圆角卡片容器，统一处理波纹 + 圆角裁剪。
class _TappableSurface extends StatelessWidget {
  const _TappableSurface({
    required this.onTap,
    required this.background,
    this.gradient,
    required this.child,
  });

  final VoidCallback onTap;
  final Color background;
  final Gradient? gradient;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool hasGradient = gradient != null;
    return Padding(
      // PageView 的页面之间留点间距，避免波纹溢出到相邻卡片
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: hasGradient ? Colors.transparent : background,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: hasGradient
              ? BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(AppDimens.radiusCard),
                  boxShadow: ForestAssetElevation.card,
                )
              : null,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.lg),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// 卡片底部一行里的小统计：上 label + 下金额。
class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.valueMinor,
    required this.labelColor,
    required this.valueColor,
  });

  final String label;
  final int valueMinor;
  final Color labelColor;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: labelColor),
        ),
        const SizedBox(height: 2),
        AnimatedMoneyText(
          Money.fromMinor(valueMinor),
          color: valueColor,
          style: theme.textTheme.titleMedium?.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// 分页指示点：当前项拉长成短条，且随滑动进度在相邻两点间**连续**过渡——
/// 每个点的宽度/颜色按「与真实页的环形距离」插值，滑到一半时两点各占
/// 一半宽度，松手或继续滑都不会跳变。
///
/// 双向循环卡（children 头尾各复制一份）也在同一线性插值里处理：
/// 副本位置经取模折回 0..count 的环形空间，从最后一张滑向第一张时
/// 第一个点会先渐宽，与正向滑动视觉一致。
class _PageDots extends StatelessWidget {
  const _PageDots({required this.controller, required this.count});

  final PageController controller;
  final int count;

  @override
  Widget build(BuildContext context) {
    final Color inactive = Theme.of(context).colorScheme.outline;
    const Color active = AppPalette.primary;

    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? _) {
        // 真实页的连续位置：children 即四张真实卡（无头尾副本），故直接用
        // `page % count` 折成 [0, count) 的环形位置——大初始页码下 page 恒正，
        // 环形取模让向左滑到「首卡之前」自然接到「尾卡」、反之亦然，无跳变。
        double pos = (controller.initialPage % count).toDouble();
        if (controller.hasClients) {
          final double? page = controller.page;
          if (page != null) {
            pos = page % count;
            if (pos < 0) pos += count;
          }
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List<Widget>.generate(count, (int i) {
            // 与第 i 点的环形最短距离，收敛到 [-count/2, count/2]。
            double d = (pos - i) % count;
            if (d < 0) d += count;
            if (d > count / 2) d -= count;

            // t=1 正好停在当前页（长条高亮），t=0 完全无关（短点置灰）。
            final double t = (1 - d.abs()).clamp(0.0, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 6 + 12 * t,
              height: 6,
              decoration: BoxDecoration(
                color: Color.lerp(inactive, active, t)!,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        );
      },
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: FilledButton.icon(
            onPressed: () => openRecordSheet(context),
            icon: const LineGlyph(Icons.add),
            label: const Text('记一笔'),
          ),
        ),
      ],
    );
  }
}
