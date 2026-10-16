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
                return TxnSlidableGroup(
                  child: Column(
                    children: list
                        .take(5)
                        .map(
                          (Transaction txn) => TxnSlidable(
                            txn: txn,
                            child: TransactionTile(
                              transaction: txn,
                              onTap: () =>
                                  TransactionDetailSheet.show(context, txn),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
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
/// 第 33 批：四张卡**循环滑动**——PageView 到边界即停，用户从最后一张
/// 左滑想回第一张必须滑回四页。第 41 批升级：头尾**双向**复制——
/// children 为 [第4张副本, 卡0..3, 第1张副本]（6 页），initialPage 仍在
/// 原位；滑到头部副本(0)无动画跳回真实最后一页(4)，滑到尾部副本(5)无动画
/// 跳到真实第一页(1)——副本与原型视觉完全相同，用户无感，两个方向都能循环。
/// 指示点取 (i − 1) % 4 映射回真实页（Dart 取模恒非负，i=0 时得 3）。
class _SwipeCards extends ConsumerStatefulWidget {
  const _SwipeCards();

  @override
  ConsumerState<_SwipeCards> createState() => _SwipeCardsState();
}

class _SwipeCardsState extends ConsumerState<_SwipeCards> {
  static const double _cardHeight = 184;

  /// 真实卡片数（指示点数）。PageView children 长度 = 真实数 + 2——头尾各
  /// 复制一份用于双向循环，见类文档。
  static const int _pageCount = 4;

  /// 头副本下标 / 尾副本下标（真实页分别落在 1..4）。
  static const int _headCopy = 0;
  static const int _tailCopy = _pageCount + 1;

  // 默认停在「本月收支」卡（children 顺序：0 支出预算 / 1 收入目标 / 2 收支 / 3 资产）。
  // 头部多了一份副本，原位 = 真实下标 + 1。
  final PageController _pageController = PageController(initialPage: 3);
  int _currentPage = 2;

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
          child: PageView(
            controller: _pageController,
            onPageChanged: (int i) {
              // 双向循环：滑到头部/尾部副本区时无动画跳回对应真实页。
              // jumpToPage 自身会再触发一次 onPageChanged（目标页在 1..4），
              // 此时不满足两个跳转条件，仅重复 setState 相同值，安全。
              if (i == _headCopy) {
                _pageController.jumpToPage(_pageCount);
              } else if (i == _tailCopy) {
                _pageController.jumpToPage(1);
              }
              setState(() => _currentPage = (i - 1) % _pageCount);
            },
            // 头尾各复制一份实现双向循环；副本与原型视觉相同，跳回时用户无感。
            // 下标：0=第4张副本 / 1..4=真实四卡 / 5=第1张副本。
            children: <Widget>[
              _AssetsCard(
                totalAssets: assetsMinor,
                totalLiabilities: liabilitiesMinor,
                netAssets: netMinor - borrowInOngoing,
                onTap: () => context.push(Routes.accounts),
              ),
              _BudgetCard(
                summary: expenseBudget,
                onTap: () => context.push(Routes.budget),
              ),
              _IncomeTargetCard(
                summary: incomeTarget,
                onTap: () => context.push(Routes.budget),
              ),
              _IncomeExpenseCard(
                income: income,
                expense: expense,
                onTap: () => context.push(Routes.ledger),
              ),
              _AssetsCard(
                totalAssets: assetsMinor,
                totalLiabilities: liabilitiesMinor,
                netAssets: netMinor - borrowInOngoing,
                onTap: () => context.push(Routes.accounts),
              ),
              _BudgetCard(
                summary: expenseBudget,
                onTap: () => context.push(Routes.budget),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.sm),
        _PageDots(
          controller: _pageController,
          count: _pageCount,
          current: _currentPage,
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

/// 分页指示点：当前页拉长且高亮，其余短灰。
class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.controller,
    required this.count,
    required this.current,
  });

  final PageController controller;
  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(count, (int i) {
        final bool active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active
                ? AppPalette.primary
                : Theme.of(context).colorScheme.outline,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
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
