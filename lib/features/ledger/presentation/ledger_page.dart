import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/errors/failures.dart';
import '../../../../shared/models/money.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/calendar_sheet.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../theme/app_colors.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../record/presentation/record_sheet.dart';
import '../../categories/providers/categories_providers.dart';
import '../providers/ledger_providers.dart';
import 'ledger_filter_page.dart';
import 'transaction_detail_sheet.dart';
import 'widgets/transaction_tile.dart';

/// 账单页（小青账布局）：
/// 顶部居中标题「账单」+ 右侧搜索；副标题行左侧周期切换、右侧筛选入口；
/// 其下是「周期支出 / 周期收入 + 支出柱状图」统计卡与「周期结余 / 日均支出」卡；
/// 最后是「账单明细」按日分组列表（侧滑删除、按时间 / 按金额排序）。
/// 周期支持：周账单 / 月账单 / 年账单 / 自定义起止。
class LedgerPage extends ConsumerStatefulWidget {
  const LedgerPage({super.key});

  @override
  ConsumerState<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends ConsumerState<LedgerPage> {
  /// 图表选中的桶：日粒度=当天 0 点；月粒度=当月 1 号。null=未手动选。
  DateTime? _selectedBucket;

  /// 明细排序：false=按时间（默认），true=按金额。
  bool _sortByAmount = false;

  /// 月模式柱状图横向滚动控制器（柱条 + 日期行整体滚动）。
  ScrollController? _chartScrollCtrl;

  @override
  void dispose() {
    _chartScrollCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LedgerPeriod period = ref.watch(ledgerPeriodProvider);
    final AsyncValue<List<Transaction>> txnsAsync =
        ref.watch(periodTransactionsProvider);
    final AsyncValue<int> income = ref.watch(periodIncomeProvider);
    final AsyncValue<int> expense = ref.watch(periodExpenseProvider);
    final LedgerAdvancedFilter? advFilter = ref.watch(ledgerAdvancedFilterProvider);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('账单'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => showAppToast(context, '搜索功能将在后续版本提供'),
          ),
        ],
      ),
      body: txnsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace? s) => Center(child: Text('加载失败：$e')),
        data: (List<Transaction> all) {
          final _PeriodStats stats = _PeriodStats.from(all);
          final Map<String, Category> catById = <String, Category>{
            for (final Category c in ref.watch(allCategoriesProvider).value ??
                const <Category>[])
              c.id: c,
          };
          final List<Transaction> list =
              _applyFilter(all, advFilter, catById);
          if (_sortByAmount) {
            // 按金额（实付口径）降序；并列时按时间倒序兜底。
            list.sort((Transaction a, Transaction b) {
              final int am = a.amountMinor - a.discountMinor;
              final int bm = b.amountMinor - b.discountMinor;
              if (am != bm) return bm - am;
              return b.occurredAt - a.occurredAt;
            });
          }

          return CustomScrollView(
            slivers: <Widget>[
              // ── 副标题行：左周期切换 / 右筛选 ──
              SliverToBoxAdapter(
                  child: _subtitleRow(context, period, advFilter)),
              // ── 统计卡：周期收支 + 选中日/月摘要 + 支出柱状图 ──
              SliverToBoxAdapter(
                child: _statsCard(context, stats, income, expense, period),
              ),
              // ── 周期结余 / 日均支出卡 ──
              SliverToBoxAdapter(
                child: _balanceCard(income, expense, period),
              ),
              // ── 账单明细节头 + 排序胶囊 ──
              SliverToBoxAdapter(child: _detailHeader(list.length)),
              if (list.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 72),
                    child: EmptyState(message: '当前周期暂无符合条件的账单'),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: list.length,
                  itemBuilder: (BuildContext context, int index) {
                    final Transaction txn = list[index];
                    final bool showHeader = index == 0 ||
                        !_isSameDay(list[index - 1].occurredAt, txn.occurredAt);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (showHeader) _dayHeader(txn.occurredAt, list),
                        Slidable(
                          key: ValueKey<String>(txn.id),
                          endActionPane: ActionPane(
                            motion: const DrawerMotion(),
                            children: <Widget>[
                              SlidableAction(
                                onPressed: (_) => _delete(context, txn),
                                backgroundColor: AppPalette.expense,
                                foregroundColor:
                                    Theme.of(context).colorScheme.onPrimary,
                                icon: Icons.delete_outline,
                                label: '删除',
                              ),
                            ],
                          ),
                          child: TransactionTile(
                            transaction: txn,
                            onTap: () =>
                                TransactionDetailSheet.show(context, txn),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => openRecordSheet(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  // ────────────────────────── 副标题行 ──────────────────────────

  Widget _subtitleRow(
      BuildContext context, LedgerPeriod period, LedgerAdvancedFilter? advFilter) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceLg,
        AppDimens.spaceXs,
        AppDimens.spaceLg,
        AppDimens.spaceSm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          // 左：周期切换入口「2026年9月 ˅」
          InkWell(
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            onTap: () => _pickPeriod(context, period),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceXs,
                vertical: 4,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    period.label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppPalette.textPrimary,
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    size: 20,
                    color: AppPalette.textPrimary,
                  ),
                ],
              ),
            ),
          ),
          // 右：筛选入口（跳转独立筛选页）
          InkWell(
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            onTap: () => _openFilterPage(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceXs,
                vertical: 4,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.tune,
                    size: 18,
                    color: (advFilter?.isEmpty ?? true)
                        ? AppPalette.textPrimary
                        : AppPalette.ctaGreen,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    advFilter == null || advFilter.isEmpty
                        ? '筛选'
                        : '筛选(${advFilter.conditionCount})',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: (advFilter?.isEmpty ?? true)
                          ? AppPalette.textPrimary
                          : AppPalette.ctaGreen,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────── 统计卡 ──────────────────────────

  /// 图表是否使用月粒度柱：年账单 / 跨度超 62 天的自定义。
  bool _useMonthlyBars(LedgerPeriod period) =>
      period.mode == LedgerPeriodMode.year || period.dayCount > 62;

  Widget _statsCard(
    BuildContext context,
    _PeriodStats stats,
    AsyncValue<int> income,
    AsyncValue<int> expense,
    LedgerPeriod period,
  ) {
    final ThemeData theme = Theme.of(context);
    final String prefix = period.prefix;
    final int expenseMinor = expense.valueOrNull ?? 0;
    final int incomeMinor = income.valueOrNull ?? 0;
    final bool monthly = _useMonthlyBars(period);

    // 选中桶：手动选且在周期内 → 用之；否则默认「最近有账目」的日 / 月。
    DateTime effective;
    if (_selectedBucket != null &&
        !_selectedBucket!.isBefore(period.start) &&
        _selectedBucket!.isBefore(period.end)) {
      effective = _selectedBucket!;
    } else if (monthly) {
      final DateTime? last = stats.lastActiveDay;
      effective = last == null
          ? DateTime(period.start.year, period.start.month)
          : DateTime(last.year, last.month);
    } else {
      effective = stats.lastActiveDay ?? period.start;
    }

    final int onBucketExpense = monthly
        ? stats.expenseInMonth(effective.year, effective.month)
        : stats.expenseOnDay(effective);
    final int onBucketIncome = monthly
        ? stats.incomeInMonth(effective.year, effective.month)
        : stats.incomeOnDay(effective);
    final String bucketLabel = monthly
        ? '${effective.year}年${effective.month}月'
        : '${effective.month}月${effective.day}日';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg),
      child: Container(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        decoration: BoxDecoration(
          color: AppPalette.cream,
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          border: Border.all(color: AppPalette.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                _dotAmount('${prefix}支出', Money.fromMinor(expenseMinor),
                    color: AppPalette.expense),
                const Spacer(),
                _dotAmount('${prefix}收入', Money.fromMinor(incomeMinor),
                    color: AppPalette.income),
              ],
            ),
            // 选中日 / 月的收支摘要行
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '$bucketLabel'
                '  支出 ${Money.fromMinor(onBucketExpense).format()}'
                '  收入 ${Money.fromMinor(onBucketIncome).format()}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppPalette.textTertiary),
              ),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            _periodBars(context, stats, period, monthly, effective),
          ],
        ),
      ),
    );
  }

  Widget _dotAmount(String label, Money money, {required Color color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label ${money.format()}',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  /// 支出柱状图：日粒度（周 7 柱 / 月 28-31 柱 / 短自定义）或月粒度（年 12 柱 / 长自定义）。
  /// 点击柱子切换选中，再点一次取消（命中列按横向比例换算）。
  Widget _periodBars(
    BuildContext context,
    _PeriodStats stats,
    LedgerPeriod period,
    bool monthly,
    DateTime effective,
  ) {
    final int count; // 柱子数量
    final double maxY;
    final List<double> values = <double>[];

    if (monthly) {
      // 月粒度：周期内逐月支出。
      final List<DateTime> months = <DateTime>[];
      DateTime m = DateTime(period.start.year, period.start.month);
      while (m.isBefore(period.end)) {
        months.add(m);
        values.add(stats.expenseInMonth(m.year, m.month).toDouble());
        m = DateTime(m.year, m.month + 1);
      }
      count = months.length;
      maxY = (values.fold<double>(0, (double a, double b) => a > b ? a : b)) *
          1.15;
      // 选中月索引：按年差 ×12 + 月差精确换算。
      final int selMonth = (effective.year - months.first.year) * 12 +
          (effective.month - months.first.month);

      return _barChart(
        count: count,
        values: values,
        maxY: maxY <= 0 ? 100 : maxY,
        selectedIndex: selMonth.clamp(0, count - 1),
        labelFor: (int i) {
          final DateTime m0 = months[i];
          final bool last = i == count - 1;
          if (count > 12) {
            return (i % 3 == 0 || last)
                ? '${m0.year}年${m0.month}月'
                : null;
          }
          return (i % 3 == 0 || last) ? '${m0.month}月' : null;
        },
        onTapIndex: (int i) => setState(() {
          final DateTime m0 = months[i];
          final DateTime bucket = DateTime(m0.year, m0.month);
          _selectedBucket = _selectedBucket == bucket ? null : bucket;
        }),
      );
    }

    // 日粒度。
    for (int i = 0; i < period.dayCount; i++) {
      final DateTime d = period.start.add(Duration(days: i));
      values.add(stats.expenseOnDay(d).toDouble());
    }
    count = period.dayCount;
    maxY = (values.fold<double>(0, (double a, double b) => a > b ? a : b)) *
        1.15;
    final int selIndex =
        DateTime(effective.year, effective.month, effective.day)
                .difference(DateTime(period.start.year, period.start.month,
                    period.start.day))
                .inDays
            .clamp(0, count - 1);
    const List<String> weekdayLabels = <String>[
      '周一', '周二', '周三', '周四', '周五', '周六', '周日',
    ];

    return _barChart(
      count: count,
      values: values,
      maxY: maxY <= 0 ? 100 : maxY,
      selectedIndex: selIndex,
      labelFor: (int i) {
        if (period.mode == LedgerPeriodMode.week) return weekdayLabels[i];
        final DateTime d = period.start.add(Duration(days: i));
        if (period.mode == LedgerPeriodMode.month) {
          final int day = d.day;
          final Set<int> labels = <int>{
            1,
            for (int x = 8; x < count; x += 7) x,
          };
          if (!labels.contains(day)) return null;
          // 只显示日期不显示月份（如「1日 / 8日」），标签更短、间距更宽松。
          return '$day日';
        }
        // 自定义（短区间）：首、每第 7 根、末。
        if (i == 0 || i % 7 == 0 || i == count - 1) {
          return '${d.month}月${d.day}日';
        }
        return null;
      },
      onTapIndex: (int i) => setState(() {
        final DateTime d = period.start.add(Duration(days: i));
        _selectedBucket = _selectedBucket == d ? null : d;
      }),
    );
  }

  /// 柱状图：短周期（周 / 年，≤20 桶）铺满整卡；月模式（>20 桶）柱条与
  /// 日期行一起放进横向滚动视图（每天固定 20px 栅距，间距均匀），
  /// 超出屏幕左右滑动，柱与日期保持对齐；点击柱 / 日期选中该天。
  Widget _barChart({
    required int count,
    required List<double> values,
    required double maxY,
    required int selectedIndex,
    required String? Function(int) labelFor,
    required void Function(int) onTapIndex,
  }) {
    final bool scrollable = count > 20;
    const double cellW = 20.0;

    Widget buildChart(double width) => BarChart(
          BarChartData(
            maxY: maxY,
            alignment: BarChartAlignment.spaceAround,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: const FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            barTouchData: BarTouchData(enabled: false),
            barGroups: <BarChartGroupData>[
              for (int i = 0; i < count; i++)
                BarChartGroupData(
                  x: i,
                  barRods: <BarChartRodData>[
                    BarChartRodData(
                      toY: values[i],
                      width: scrollable ? 6 : 14,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(2),
                      ),
                      color: i == selectedIndex
                          ? AppPalette.expense
                          : AppPalette.expense.withValues(alpha: 0.55),
                    ),
                  ],
                ),
            ],
          ),
        );

    if (!scrollable) {
      return SizedBox(
        height: 150,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (TapUpDetails details) {
            final RenderBox? box = context.findRenderObject() as RenderBox?;
            if (box == null) return;
            final double dx = box.globalToLocal(details.globalPosition).dx;
            final int index =
                ((dx / box.size.width) * count).floor().clamp(0, count - 1);
            onTapIndex(index);
          },
          child: Column(
            children: <Widget>[
              Expanded(child: buildChart(double.infinity)),
              SizedBox(
                height: 24,
                child: Row(
                  children: <Widget>[
                    for (int i = 0; i < count; i++)
                      Expanded(
                        child: Center(
                          child: Text(
                            labelFor(i) ?? '',
                            maxLines: 1,
                            softWrap: false,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppPalette.textTertiary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 月模式：柱条 + 日期行整体横向滚动（共用同一栅距，滚动时保持对齐）。
    final ScrollController ctrl = _chartScrollCtrl ??= ScrollController();
    final double contentW = count * cellW;

    // 首帧 / 选中变化后：若选中日不在可视区，平移滚动到中间。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !ctrl.hasClients || selectedIndex < 0) return;
      final double target = (selectedIndex + 0.5) * cellW;
      final double viewport = ctrl.position.viewportDimension;
      final double cur = ctrl.offset;
      if (target < cur + cellW / 2 || target > cur + viewport - cellW / 2) {
        ctrl.jumpTo(
          (target - viewport / 2)
              .clamp(0.0, ctrl.position.maxScrollExtent),
        );
      }
    });

    return SizedBox(
      height: 150,
      child: SingleChildScrollView(
        controller: ctrl,
        scrollDirection: Axis.horizontal,
        child: Builder(
          builder: (BuildContext boxCtx) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (TapUpDetails details) {
              final RenderBox? box = boxCtx.findRenderObject() as RenderBox?;
              if (box == null) return;
              final double dx = box.globalToLocal(details.globalPosition).dx;
              final int index = (dx / cellW).floor().clamp(0, count - 1);
              onTapIndex(index);
            },
            child: SizedBox(
              width: contentW,
              height: 150,
              child: Column(
                children: <Widget>[
                  SizedBox(height: 126, child: buildChart(contentW)),
                  SizedBox(
                    height: 24,
                    child: Row(
                      children: <Widget>[
                        for (int i = 0; i < count; i++)
                          SizedBox(
                            width: cellW,
                            child: Center(
                              child: Text(
                                labelFor(i) ?? '',
                                maxLines: 1,
                                softWrap: false,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppPalette.textTertiary,
                                ),
                              ),
                            ),
                          ),
                      ],
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

  // ────────────────────── 周期结余 / 日均支出卡 ──────────────────────

  Widget _balanceCard(
    AsyncValue<int> income,
    AsyncValue<int> expense,
    LedgerPeriod period,
  ) {
    final int expenseMinor = expense.valueOrNull ?? 0;
    final int balanceMinor = (income.valueOrNull ?? 0) - expenseMinor;
    final String prefix = period.prefix;

    // 日均：周期已结束 → 按全周期；进行中或含今天 → 按已过天数。
    final DateTime now = DateTime.now();
    final int totalDays = period.dayCount;
    int elapsed = totalDays;
    if (!now.isBefore(period.start)) {
      elapsed = now.difference(period.start).inDays + 1;
      if (elapsed > totalDays) elapsed = totalDays;
    }
    final int dailyAvgMinor =
        expenseMinor > 0 && elapsed > 0 ? expenseMinor ~/ elapsed : 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceLg,
        AppDimens.spaceSm,
        AppDimens.spaceLg,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceLg,
          vertical: AppDimens.spaceMd,
        ),
        decoration: BoxDecoration(
          color: AppPalette.cream,
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          border: Border.all(color: AppPalette.hairline),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text.rich(
              TextSpan(
                text: '${prefix}结余：',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppPalette.textPrimary,
                ),
                children: <InlineSpan>[
                  TextSpan(
                    text: Money.fromMinor(balanceMinor).format(),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: balanceMinor >= 0
                          ? AppPalette.income
                          : AppPalette.expense,
                    ),
                  ),
                ],
              ),
            ),
            Text.rich(
              TextSpan(
                text: '日均支出：',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppPalette.textPrimary,
                ),
                children: <InlineSpan>[
                  TextSpan(
                    text: Money.fromMinor(dailyAvgMinor).format(),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.expense,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────── 账单明细 ──────────────────────────

  Widget _detailHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceLg,
        AppDimens.spaceLg,
        AppDimens.spaceLg,
        AppDimens.spaceXs,
      ),
      child: Row(
        children: <Widget>[
          Text(
            '账单明细',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppPalette.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count笔',
            style: const TextStyle(
              fontSize: 12,
              color: AppPalette.textTertiary,
            ),
          ),
          const Spacer(),
          // 排序切换胶囊：按时间 / 按金额
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => setState(() => _sortByAmount = !_sortByAmount),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: AppPalette.chipLine),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _sortByAmount ? '按金额' : '按时间',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppPalette.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 日分组头：左侧「M月d日（今天/昨天）」，右侧「N笔」。
  Widget _dayHeader(int timestamp, List<Transaction> list) {
    final DateTime date = DateTime.fromMillisecondsSinceEpoch(
      timestamp,
      isUtc: true,
    ).toLocal();
    final DateTime today = DateTime.now();
    final DateTime day = DateTime(date.year, date.month, date.day);
    final DateTime today0 = DateTime(today.year, today.month, today.day);
    final String relative = day == today0
        ? '  今天'
        : day == today0.subtract(const Duration(days: 1))
            ? '  昨天'
            : '';

    int count = 0;
    for (final Transaction t in list) {
      final DateTime d =
          DateTime.fromMillisecondsSinceEpoch(t.occurredAt, isUtc: true)
              .toLocal();
      if (d.year == date.year && d.month == date.month && d.day == date.day) {
        count++;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceLg,
        AppDimens.spaceMd,
        AppDimens.spaceLg,
        AppDimens.spaceXs,
      ),
      child: Row(
        children: <Widget>[
          Text(
            '${DateFormat('M月d日').format(date)}$relative',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppPalette.textTertiary,
            ),
          ),
          const Spacer(),
          Text(
            '$count笔',
            style: const TextStyle(
              fontSize: 12,
              color: AppPalette.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────── 周期选择器（周/月/年/自定义） ────────────────────

  /// 四种周期内容区的统一高度：= 月/年宫格自然高度（3 行 × 40 + 2 × 8 间距 + 14 内边距）。
  static const double _kSheetBodyHeight = 154;

  /// 周轮拨每行高度，与中间选中框高度一致。
  static const double _kW = 44;

  /// 周列表上下留白，使选中框固定落在内容区正中。
  static const double _kWeekCenterPad = (_kSheetBodyHeight - _kW) / 2;
  /// 周期选择：调用全局共用日历组件（纯周期模式 showDayView:false，
  /// 周/月/年/自定义），确认后写回 [ledgerPeriodProvider]。
  Future<void> _pickPeriod(BuildContext context, LedgerPeriod current) async {
    final CalendarPeriodMode m = switch (current.mode) {
      LedgerPeriodMode.week => CalendarPeriodMode.week,
      LedgerPeriodMode.month => CalendarPeriodMode.month,
      LedgerPeriodMode.year => CalendarPeriodMode.year,
      LedgerPeriodMode.custom => CalendarPeriodMode.custom,
    };
    final CalendarSelection? r = await CalendarSheet.show(
      context,
      mode: CalendarSheetMode.day,
      showDayView: false,
      headerTitle: '账单周期',
      initialPeriod: CalendarPeriod(m, current.start, current.end),
      weekStart: CalendarWeekStart.monday,
    );
    if (r is CalendarPeriod) {
      final CalendarPeriod cp = r;
      final CalendarPeriodMode cm = cp.mode;
      final LedgerPeriodMode lm = switch (cm) {
        CalendarPeriodMode.week => LedgerPeriodMode.week,
        CalendarPeriodMode.month => LedgerPeriodMode.month,
        CalendarPeriodMode.year => LedgerPeriodMode.year,
        CalendarPeriodMode.custom => LedgerPeriodMode.custom,
      };
      ref.read(ledgerPeriodProvider.notifier).state =
          LedgerPeriod(mode: lm, start: cp.start, end: cp.end);
      setState(() => _selectedBucket = null);
    }
  }



  // ────────────────────────── 筛选 ──────────────────────────

  /// 打开独立筛选页；「查询」带回结果后写入 provider 触发明细刷新。
  Future<void> _openFilterPage(BuildContext context) async {
    final LedgerAdvancedFilter? result =
        await Navigator.of(context, rootNavigator: true)
            .push<LedgerAdvancedFilter>(
      MaterialPageRoute<LedgerAdvancedFilter>(
        builder: (BuildContext _) => LedgerFilterPage(
          initial: ref.read(ledgerAdvancedFilterProvider),
        ),
      ),
    );
    if (result != null) {
      ref.read(ledgerAdvancedFilterProvider.notifier).state = result;
    }
  }

  // ────────────────────────── 工具 ──────────────────────────

  /// 「M月d日」短标签。

  /// 按高级筛选条件过滤明细（共享口径见
  /// [applyLedgerAdvancedFilter]，账单页与报表页一致）。
  List<Transaction> _applyFilter(
      List<Transaction> all, LedgerAdvancedFilter? f,
      Map<String, Category> catById) {
    return applyLedgerAdvancedFilter(all, f, catById);
  }

  bool _isSameDay(int a, int b) {
    final DateTime da =
        DateTime.fromMillisecondsSinceEpoch(a, isUtc: true).toLocal();
    final DateTime db =
        DateTime.fromMillisecondsSinceEpoch(b, isUtc: true).toLocal();
    return da.year == db.year && da.month == db.month && da.day == db.day;
  }

  Future<void> _delete(BuildContext context, Transaction txn) async {
    try {
      await ref.read(transactionRepositoryProvider).remove(txn.id);
      if (context.mounted) {
        showAppToast(context, '已删除');
      }
    } on AppFailure catch (e) {
      if (context.mounted) {
        showAppToast(context, e.message);
      }
    }
  }
}

/// 周期统计聚合：日支出 / 日收入 / 最大日支出 / 最近有账目日。
///
/// 统计口径与 `watchTotalInRange` 对齐：排除不计收支项，
/// 支出按实付（amount − discount）计入。
class _PeriodStats {
  const _PeriodStats({
    required this.dailyExpense,
    required this.dailyIncome,
    required this.lastActiveDay,
  });

  factory _PeriodStats.from(List<Transaction> txns) {
    final Map<DateTime, int> dailyExpense = <DateTime, int>{};
    final Map<DateTime, int> dailyIncome = <DateTime, int>{};
    DateTime? lastActiveDay;
    int lastActiveAt = -1;

    for (final Transaction t in txns) {
      if (t.excludeFromStats || t.type == TxnType.transfer) continue;
      final DateTime local = DateTime.fromMillisecondsSinceEpoch(
        t.occurredAt,
        isUtc: true,
      ).toLocal();
      final DateTime day = DateTime(local.year, local.month, local.day);
      if (t.occurredAt > lastActiveAt) {
        lastActiveAt = t.occurredAt;
        lastActiveDay = day;
      }
      switch (t.type) {
        case TxnType.expense:
          dailyExpense[day] = (dailyExpense[day] ?? 0) +
              (t.amountMinor - t.discountMinor);
        case TxnType.income:
          dailyIncome[day] = (dailyIncome[day] ?? 0) + t.amountMinor;
        case TxnType.transfer:
          break;
      }
    }
    return _PeriodStats(
      dailyExpense: dailyExpense,
      dailyIncome: dailyIncome,
      lastActiveDay: lastActiveAt >= 0 ? lastActiveDay : null,
    );
  }

  final Map<DateTime, int> dailyExpense;
  final Map<DateTime, int> dailyIncome;

  /// 最近有账目的自然日（0 点）。
  final DateTime? lastActiveDay;

  int expenseOnDay(DateTime day) => dailyExpense[day] ?? 0;

  int incomeOnDay(DateTime day) => dailyIncome[day] ?? 0;

  int expenseInMonth(int year, int month) {
    int sum = 0;
    dailyExpense.forEach((DateTime day, int v) {
      if (day.year == year && day.month == month) sum += v;
    });
    return sum;
  }

  int incomeInMonth(int year, int month) {
    int sum = 0;
    dailyIncome.forEach((DateTime day, int v) {
      if (day.year == year && day.month == month) sum += v;
    });
    return sum;
  }
}
