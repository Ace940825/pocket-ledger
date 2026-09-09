import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../database/app_database.dart';
import '../../../database/daos/transactions_dao.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/money_text.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../../ledger/providers/ledger_providers.dart';
import '../providers/report_providers.dart';

/// 财务报表：月度收支 + 近 12 月趋势 + 支出分类占比 + 模块下钻 + 资产负债。
///
/// 所有聚合都在本地 SQLite 完成，**不依赖任何云端计算**，
/// 因此离线可用、响应毫秒级，也不产生任何服务端费用。
class ReportPage extends ConsumerWidget {
  const ReportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime month = ref.watch(selectedMonthProvider);
    final AsyncValue<int> income = ref.watch(monthIncomeProvider);
    final AsyncValue<int> expense = ref.watch(monthExpenseProvider);
    final AsyncValue<List<CategoryTotal>> totals =
        ref.watch(monthCategoryTotalsProvider);
    final Map<String, Category> categories =
        ref.watch(categoryMapProvider).valueOrNull ?? <String, Category>{};

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('报表'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(96),
            child: Column(
              children: <Widget>[
                _MonthSwitcher(month: month),
                const TabBar(
                  tabs: <Widget>[
                    Tab(text: '月度'),
                    Tab(text: '趋势'),
                    Tab(text: '资产'),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            _MonthlyTab(
              income: income,
              expense: expense,
              totals: totals,
              categories: categories,
              month: month,
            ),
            const _TrendTab(),
            const _AssetsTab(),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────── 月度 ──────────────────────────────

class _MonthlyTab extends ConsumerWidget {
  const _MonthlyTab({
    required this.income,
    required this.expense,
    required this.totals,
    required this.categories,
    required this.month,
  });

  final AsyncValue<int> income;
  final AsyncValue<int> expense;
  final AsyncValue<List<CategoryTotal>> totals;
  final Map<String, Category> categories;
  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ModuleTotal>> modules =
        ref.watch(moduleTotalsProvider);

    return ListView(
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.spaceLg),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _SummaryItem(
                    label: '收入',
                    money: Money.fromMinor(income.valueOrNull ?? 0),
                    color: AppColors.income,
                  ),
                ),
                Expanded(
                  child: _SummaryItem(
                    label: '支出',
                    money: Money.fromMinor(expense.valueOrNull ?? 0),
                    color: AppColors.expense,
                  ),
                ),
                Expanded(
                  child: _SummaryItem(
                    label: '结余',
                    money: Money.fromMinor(
                      (income.valueOrNull ?? 0) - (expense.valueOrNull ?? 0),
                    ),
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimens.spaceLg),
        _sectionTitle(context, '本月支出分类占比'),
        const SizedBox(height: AppDimens.spaceMd),
        totals.when(
          data: (List<CategoryTotal> list) {
            final List<CategoryTotal> visible = list
                .where((CategoryTotal t) => t.totalMinor > 0)
                .toList(growable: false);
            if (visible.isEmpty) {
              return const SizedBox(
                height: 220,
                child: EmptyState(message: '本月还没有支出记录'),
              );
            }
            final int sum = visible.fold<int>(
              0,
              (int acc, CategoryTotal t) => acc + t.totalMinor,
            );
            return Column(
              children: <Widget>[
                SizedBox(
                  height: 220,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 56,
                      sections: <PieChartSectionData>[
                        for (int i = 0; i < visible.length; i++)
                          _pieSection(visible[i], sum, i),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppDimens.spaceLg),
                for (final CategoryTotal t in visible)
                  _CategoryRankTile(
                    total: t,
                    name: categories[t.categoryId]?.name ?? '未分类',
                    share: sum == 0 ? 0 : t.totalMinor / sum,
                  ),
              ],
            );
          },
          loading: () => const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (Object e, StackTrace? s) => SizedBox(
            height: 220,
            child: Center(child: Text('加载失败：$e')),
          ),
        ),
        const SizedBox(height: AppDimens.spaceLg),
        _sectionTitle(context, '本月支出按模块'),
        const SizedBox(height: AppDimens.spaceMd),
        modules.when(
          data: (List<ModuleTotal> list) {
            if (list.isEmpty) {
              return const EmptyState(message: '本月还没有支出记录');
            }
            final int sum = list.fold<int>(
              0,
              (int acc, ModuleTotal m) => acc + m.totalMinor,
            );
            return Column(
              children: <Widget>[
                for (final ModuleTotal m in list)
                  _ModuleTile(total: m, share: sum == 0 ? 0 : m.totalMinor / sum),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object e, StackTrace? s) => Center(child: Text('加载失败：$e')),
        ),
      ],
    );
  }

  PieChartSectionData _pieSection(CategoryTotal t, int sum, int i) {
    final double share = sum == 0 ? 0 : t.totalMinor / sum;
    return PieChartSectionData(
      value: t.totalMinor.toDouble(),
      color: AppColors.chartPalette[i % AppColors.chartPalette.length],
      radius: 46,
      title: '${(share * 100).round()}%',
      titleStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Text(
        text,
        style: Theme.of(context).textTheme.titleMedium,
      );
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({required this.total, required this.share});

  final ModuleTotal total;
  final double share;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(total.module.label),
              Text(
                '${Money.fromMinor(total.totalMinor).format()}'
                '  ${(share * 100).round()}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceXs),
          LinearProgressIndicator(
            value: share.clamp(0.0, 1.0),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────── 趋势 ──────────────────────────────

/// 近 12 个月收支趋势。
///
/// 用 `StreamProvider` 转 `AsyncValue` 是为了复用加载/错误三态，
/// 避免每个图表各写一份 when 分支。
final AutoDisposeStreamProvider<List<MonthTotal>> trendProvider =
    StreamProvider.autoDispose<List<MonthTotal>>(
  (Ref ref) => ref.watch(monthlyTrendProvider(12)),
);

class _TrendTab extends ConsumerWidget {
  const _TrendTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<MonthTotal>> trend = ref.watch(trendProvider);

    return trend.when(
      data: (List<MonthTotal> list) {
        if (list.isEmpty) {
          return const EmptyState(message: '还没有足够的数据生成趋势');
        }
        return ListView(
          padding: const EdgeInsets.all(AppDimens.spaceLg),
          children: <Widget>[
            Text('近 12 个月收支', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppDimens.spaceMd),
            SizedBox(height: 240, child: _TrendChart(data: list)),
            const SizedBox(height: AppDimens.spaceLg),
            Text('月度明细', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppDimens.spaceMd),
            for (final MonthTotal m in list.reversed) _MonthRow(total: m),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, StackTrace? s) => Center(child: Text('加载失败：$e')),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.data});

  final List<MonthTotal> data;

  @override
  Widget build(BuildContext context) {
    final double maxY = <int>[
      for (final MonthTotal m in data) ...<int>[m.incomeMinor, m.expenseMinor],
    ].fold<int>(0, (int a, int b) => a > b ? a : b).toDouble();

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY <= 0 ? 100 : maxY * 1.2,
        gridData: const FlGridData(show: true, horizontalInterval: null),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: data.length > 8 ? 2 : 1,
              getTitlesWidget: (double value, TitleMeta meta) {
                final int i = value.toInt();
                if (i < 0 || i >= data.length) return const SizedBox.shrink();
                // 'yyyy-MM' → 'M月'
                final String monthPart =
                    data[i].monthKey.split('-').elementAtOrNull(1) ?? '';
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${int.tryParse(monthPart) ?? 0}月',
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: <LineChartBarData>[
          _bar(AppColors.income, (MonthTotal m) => m.incomeMinor),
          _bar(AppColors.expense, (MonthTotal m) => m.expenseMinor),
        ],
      ),
    );
  }

  LineChartBarData _bar(Color color, int Function(MonthTotal) pick) {
    return LineChartBarData(
      color: color,
      barWidth: 2.5,
      isCurved: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
      spots: <FlSpot>[
        for (int i = 0; i < data.length; i++)
          FlSpot(i.toDouble(), pick(data[i]).toDouble()),
      ],
    );
  }
}

class _MonthRow extends StatelessWidget {
  const _MonthRow({required this.total});

  final MonthTotal total;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          SizedBox(width: 72, child: Text(total.monthKey)),
          Expanded(
            child: Text(
              '收 ${Money.fromMinor(total.incomeMinor).format()}',
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Text(
              '支 ${Money.fromMinor(total.expenseMinor).format()}',
              style: theme.textTheme.bodySmall,
            ),
          ),
          SizedBox(
            width: 96,
            child: Text(
              Money.fromMinor(total.balanceMinor).formatSigned(),
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: total.balanceMinor >= 0
                    ? AppColors.income
                    : AppColors.expense,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────── 资产 ──────────────────────────────

class _AssetsTab extends ConsumerWidget {
  const _AssetsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NetWorth netWorth = ref.watch(netWorthProvider);
    final ThemeData theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('净资产', style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                MoneyText(
                  Money.fromMinor(netWorth.netMinor),
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _Metric(
                        label: '总资产',
                        value: Money.fromMinor(netWorth.assetsMinor).format(),
                      ),
                    ),
                    Expanded(
                      child: _Metric(
                        label: '总负债',
                        value:
                            Money.fromMinor(netWorth.liabilitiesMinor).format(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimens.spaceLg),
        Text('资产构成', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppDimens.spaceMd),
        _AssetRow(
          label: '账户余额',
          icon: Icons.account_balance_wallet_outlined,
          minor: netWorth.accountMinor,
        ),
        _AssetRow(
          label: '投资市值',
          icon: Icons.trending_up,
          minor: netWorth.investmentMinor,
        ),
        _AssetRow(
          label: '物品现值',
          icon: Icons.inventory_2_outlined,
          minor: netWorth.inventoryMinor,
        ),
        const SizedBox(height: AppDimens.spaceMd),
        Text(
          '口径：资产 = 账户余额 + 投资市值 + 物品现值；'
          '负债 = 未结清的借入。借出不计入资产，避免把「别人欠我的钱」'
          '当成已经到手的钱。',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _AssetRow extends StatelessWidget {
  const _AssetRow({
    required this.label,
    required this.icon,
    required this.minor,
  });

  final String label;
  final IconData icon;
  final int minor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 20),
      title: Text(label),
      trailing: Text(Money.fromMinor(minor).format()),
    );
  }
}

// ──────────────────────────── 公共组件 ────────────────────────────

class _MonthSwitcher extends ConsumerWidget {
  const _MonthSwitcher({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => ref.read(selectedMonthProvider.notifier).state =
                DateTime(month.year, month.month - 1),
          ),
          Text(DateFormat('yyyy年M月').format(month)),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => ref.read(selectedMonthProvider.notifier).state =
                DateTime(month.year, month.month + 1),
          ),
        ],
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
    return Column(
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppDimens.spaceXs),
        MoneyText(money, color: color),
      ],
    );
  }
}

class _CategoryRankTile extends StatelessWidget {
  const _CategoryRankTile({
    required this.total,
    required this.name,
    required this.share,
  });

  final CategoryTotal total;
  final String name;
  final double share;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(name),
              Text(
                '${Money.fromMinor(total.totalMinor).format()}'
                '  ${(share * 100).round()}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceXs),
          LinearProgressIndicator(
            value: share.clamp(0.0, 1.0),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }
}
