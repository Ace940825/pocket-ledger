import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../database/app_database.dart';
import '../../../providers/app_providers.dart';
import '../../../routing/app_router.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/animated_money_text.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../../budget/providers/budget_providers.dart';
import '../../ledger/presentation/transaction_detail_sheet.dart';
import '../../ledger/presentation/widgets/transaction_tile.dart';
import '../../ledger/providers/ledger_providers.dart';
import '../../record/presentation/record_sheet.dart';
import '../../record/record_tab.dart';

/// 首页总览：顶部三张可横向滑动卡片（资产 / 预算 / 本月收支）+ 快捷入口 + 最近流水。
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
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(Routes.settings),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(syncControllerProvider.notifier).syncNow(),
        child: ListView(
          padding: const EdgeInsets.all(AppDimens.spaceLg),
          children: <Widget>[
            const FadeSlideIn(child: _SwipeCards()),
            const SizedBox(height: AppDimens.spaceLg),
            const FadeSlideIn(
              delay: Duration(milliseconds: 90),
              child: _QuickActions(),
            ),
            const SizedBox(height: AppDimens.spaceXl),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  '最近流水',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton(
                  onPressed: () => context.go(Routes.ledger),
                  child: const Text('查看全部'),
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
                return Column(
                  children: list
                      .take(5)
                      .map(
                        (Transaction txn) => TransactionTile(
                          transaction: txn,
                          onTap: () =>
                              TransactionDetailSheet.show(context, txn),
                        ),
                      )
                      .toList(growable: false),
                );
              },
              loading: () => const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
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

/// 顶部三张横向卡片：资产总览 / 本月预算 / 本月收支。
///
/// 用 [PageView] 让用户左右滑动浏览；下面接 [_PageDots] 指示当前页。
/// 把 PageController 放在 StatefulWidget 里，否则 setState 不会触发指示点更新。
class _SwipeCards extends ConsumerStatefulWidget {
  const _SwipeCards();

  @override
  ConsumerState<_SwipeCards> createState() => _SwipeCardsState();
}

class _SwipeCardsState extends ConsumerState<_SwipeCards> {
  static const double _cardHeight = 184;
  static const int _pageCount = 3;

  final PageController _pageController = PageController();
  int _currentPage = 0;

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
    // 信用卡正余额=欠款；直接读负债 provider 避免再用「资产-净资产」反推。
    final int liabilitiesMinor =
        ref.watch(totalLiabilitiesProvider).valueOrNull ?? 0;
    final BudgetSummary budget = ref.watch(currentMonthBudgetSummaryProvider);
    final int income = ref.watch(monthIncomeProvider).valueOrNull ?? 0;
    final int expense = ref.watch(monthExpenseProvider).valueOrNull ?? 0;

    return Column(
      children: <Widget>[
        SizedBox(
          height: _cardHeight,
          child: PageView(
            controller: _pageController,
            onPageChanged: (int i) => setState(() => _currentPage = i),
            children: <Widget>[
              _BudgetCard(
                summary: budget,
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
                netAssets: netMinor,
                onTap: () => context.push(Routes.accounts),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        _PageDots(
          controller: _pageController,
          count: _pageCount,
          current: _currentPage,
        ),
      ],
    );
  }
}

/// 卡片1：资产总览（深绿底）。
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
      background: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '净资产',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
          ),
          const SizedBox(height: 2),
          AnimatedMoneyText(
            Money.fromMinor(netAssets),
            color: Colors.white,
            style: theme.textTheme.headlineSmall
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Row(
            children: <Widget>[
              Expanded(
                child: _MiniStat(
                  label: '总资产',
                  valueMinor: totalAssets,
                  labelColor: Colors.white.withValues(alpha: 0.85),
                  valueColor: Colors.white,
                ),
              ),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                child: _MiniStat(
                  label: '总负债',
                  valueMinor: totalLiabilities,
                  labelColor: Colors.white.withValues(alpha: 0.85),
                  valueColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 卡片2：本月预算（蓝底）。
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
      background: AppColors.info,
      child: empty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceLg,
                ),
                child: Text(
                  '暂未设置预算，点此去设置',
                  style:
                      theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '剩余预算',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                ),
                const SizedBox(height: 2),
                AnimatedMoneyText(
                  Money.fromMinor(
                      summary.remaining >= 0 ? summary.remaining : 0),
                  color: Colors.white,
                  style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _MiniStat(
                        label: '总预算',
                        valueMinor: summary.total,
                        labelColor: Colors.white.withValues(alpha: 0.85),
                        valueColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: AppDimens.spaceMd),
                    Expanded(
                      child: _MiniStat(
                        label: '已用',
                        valueMinor: summary.spent,
                        labelColor: Colors.white.withValues(alpha: 0.85),
                        valueColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

/// 卡片3：本月收支（浅底）。
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
    return _TappableSurface(
      onTap: onTap,
      background: theme.colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '本月结余',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          AnimatedMoneyText(
            Money.fromMinor(balance),
            color: balance >= 0 ? AppColors.income : AppColors.expense,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: balance >= 0 ? AppColors.income : AppColors.expense,
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
                  labelColor: theme.colorScheme.onSurfaceVariant,
                  valueColor: AppColors.income,
                ),
              ),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                child: _MiniStat(
                  label: '支出',
                  valueMinor: expense,
                  labelColor: theme.colorScheme.onSurfaceVariant,
                  valueColor: AppColors.expense,
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
    required this.child,
  });

  final VoidCallback onTap;
  final Color background;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // PageView 的页面之间留点间距，避免波纹溢出到相邻卡片
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.spaceLg),
            child: child,
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
            color: active ? AppColors.primary : AppColors.divider,
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
            icon: const Icon(Icons.add),
            label: const Text('记一笔'),
          ),
        ),
        const SizedBox(width: AppDimens.spaceMd),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () =>
                openRecordSheet(context, initialTab: RecordTab.transfer),
            icon: const Icon(Icons.swap_horiz),
            label: const Text('转账'),
          ),
        ),
        const SizedBox(width: AppDimens.spaceMd),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => context.push(Routes.more),
            icon: const Icon(Icons.grid_view_outlined),
            label: const Text('更多'),
          ),
        ),
      ],
    );
  }
}
