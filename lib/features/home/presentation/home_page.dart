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
import '../../ledger/presentation/widgets/transaction_tile.dart';
import '../../ledger/providers/ledger_providers.dart';

/// 首页总览：净资产、本月收支、快捷入口、最近流水。
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<int> netAssets = ref.watch(netAssetsProvider);
    final AsyncValue<int> income = ref.watch(monthIncomeProvider);
    final AsyncValue<int> expense = ref.watch(monthExpenseProvider);
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
            FadeSlideIn(child: _NetAssetsCard(value: netAssets)),
            const SizedBox(height: AppDimens.spaceLg),
            FadeSlideIn(
              delay: const Duration(milliseconds: 90),
              child: _MonthSummary(income: income, expense: expense),
            ),
            const SizedBox(height: AppDimens.spaceLg),
            const FadeSlideIn(
              delay: Duration(milliseconds: 180),
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
                          onTap: () => context.push(
                            '/ledger/edit/${txn.id}',
                          ),
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

class _NetAssetsCard extends StatelessWidget {
  const _NetAssetsCard({required this.value});

  final AsyncValue<int> value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimens.spaceXl),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '净资产',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.85),
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          AnimatedMoneyText(
            Money.fromMinor(value.valueOrNull ?? 0),
            color: Colors.white,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthSummary extends StatelessWidget {
  const _MonthSummary({required this.income, required this.expense});

  final AsyncValue<int> income;
  final AsyncValue<int> expense;

  @override
  Widget build(BuildContext context) {
    final int incomeMinor = income.valueOrNull ?? 0;
    final int expenseMinor = expense.valueOrNull ?? 0;
    final int balance = incomeMinor - expenseMinor;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Row(
          children: <Widget>[
            Expanded(
              child: _SummaryItem(
                label: '收入',
                money: Money.fromMinor(incomeMinor),
                color: AppColors.income,
              ),
            ),
            Expanded(
              child: _SummaryItem(
                label: '支出',
                money: Money.fromMinor(expenseMinor),
                color: AppColors.expense,
              ),
            ),
            Expanded(
              child: _SummaryItem(
                label: '结余',
                money: Money.fromMinor(balance),
                color: balance >= 0 ? AppColors.income : AppColors.expense,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.money,
    required this.color,
  });

  final String label;
  final Money money;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppDimens.spaceXs),
        AnimatedMoneyText(money, color: color),
      ],
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
            onPressed: () => context.push(Routes.ledgerAdd),
            icon: const Icon(Icons.add),
            label: const Text('记一笔'),
          ),
        ),
        const SizedBox(width: AppDimens.spaceMd),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => context.push(Routes.transfer),
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
