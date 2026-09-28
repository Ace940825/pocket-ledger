import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../theme/app_colors.dart';
import '../../../../core/theme/forest_design_tokens.dart';
import '../../../../database/app_database.dart';
import '../../../../domain/enums.dart';
import '../../../../shared/models/money.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../providers/ledger_providers.dart';
import 'transaction_detail_sheet.dart';
import 'widgets/transaction_tile.dart';

/// 分类账单页 · 对齐参考稿（小青账「分类下全部账单」）。
///
/// 头部：圆形 ✕ 关闭 + 居中标题「分类名 年-月(共N笔)」；
/// 月份切换：‹ 2026年9月 › 左右箭头翻月（默认显示该分类最近一笔所在月，
/// 点标题年份可复位为「自动」）；
/// 账单明细节：右侧「按时间 / 按金额」胶囊，点击切换排序；
/// 按天分组：天头「M月d日 今天/星期X」+ 右侧当日「支:x / 收:x / 收支:0」，
/// 行复用 [TransactionTile]（报徽章 / 已报 / 账户名 / 不计收支、预算 /
/// 全额报销删除线 + 已报徽章），点击行进入流水明细弹窗。
class CategoryTransactionsPage extends ConsumerStatefulWidget {
  const CategoryTransactionsPage({required this.categoryId, super.key});

  final String categoryId;

  @override
  ConsumerState<CategoryTransactionsPage> createState() =>
      _CategoryTransactionsPageState();
}

enum _SortMode { time, amount }

class _CategoryTransactionsPageState
    extends ConsumerState<CategoryTransactionsPage> {
  /// null = 自动（取该分类最近一笔所在月）；设定后锁定该月。
  DateTime? _selectedMonth;
  _SortMode _sortMode = _SortMode.time;

  DateTime _effectiveMonth(List<Transaction> list) {
    if (_selectedMonth != null) return _selectedMonth!;
    if (list.isEmpty) {
      final DateTime now = DateTime.now();
      return DateTime(now.year, now.month, 1);
    }
    int latest = list.fold<int>(
      0,
      (int m, Transaction t) => t.occurredAt > m ? t.occurredAt : m,
    );
    final DateTime d =
        DateTime.fromMillisecondsSinceEpoch(latest, isUtc: true).toLocal();
    return DateTime(d.year, d.month, 1);
  }

  List<Transaction> _filterMonth(List<Transaction> list, DateTime month) =>
      list.where((Transaction t) {
        final DateTime d =
            DateTime.fromMillisecondsSinceEpoch(t.occurredAt, isUtc: true)
                .toLocal();
        return d.year == month.year && d.month == month.month;
      }).toList();

  @override
  Widget build(BuildContext context) {
    final Map<String, Category> categories =
        ref.watch(categoryMapProvider).valueOrNull ?? <String, Category>{};
    final Category? category = categories[widget.categoryId];
    final AsyncValue<List<Transaction>> listAsync =
        ref.watch(categoryTransactionsProvider(widget.categoryId));

    final List<Transaction> data =
        listAsync.valueOrNull ?? const <Transaction>[];
    final DateTime month = _effectiveMonth(data);
    final List<Transaction> filtered = _filterMonth(data, month);
    // 全局排序：按时间倒序，或按金额（绝对值）倒序。
    if (_sortMode == _SortMode.time) {
      filtered.sort((Transaction a, Transaction b) =>
          b.occurredAt.compareTo(a.occurredAt));
    } else {
      filtered.sort((Transaction a, Transaction b) =>
          b.amountMinor.compareTo(a.amountMinor));
    }

    final int count = filtered.length;
    final String name = category?.name ?? '分类';

    return Scaffold(
      backgroundColor: ForestBg.paper,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _buildHeader(context, name, month, count),
            _buildMonthBar(month),
            _buildSectionBar(),
            Expanded(
              child: listAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (Object e, StackTrace _) => Center(
                  child: Text('加载失败 $e',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textTertiary)),
                ),
                data: (_) {
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        _selectedMonth == null
                            ? '该分类下暂无账单'
                            : '该分类 ${month.year}年${month.month}月暂无账单',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textTertiary),
                      ),
                    );
                  }
                  return _buildDayGroups(filtered);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 头部：✕ + 居中标题（含月份） ─────────────────────
  Widget _buildHeader(
    BuildContext context,
    String name,
    DateTime month,
    int count,
  ) {
    final String monthSuffix = '${month.year}-${month.month}';
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Positioned(
            left: 14,
            child: GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.078),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.close,
                    size: 20, color: ForestNeutral.textPrimary),
              ),
            ),
          ),
          Center(
            child: Text(
              '$name $monthSuffix(共$count笔)',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: ForestNeutral.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 月份切换 ‹ 年-月 › ───────────────────────────────
  Widget _buildMonthBar(DateTime month) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.chevron_left,
                size: 20, color: ForestNeutral.textPrimary),
            splashRadius: 18,
            onPressed: () => setState(() => _selectedMonth =
                DateTime(month.year, month.month - 1, 1)),
          ),
          GestureDetector(
            // 点年份复位为「自动」（最近一笔所在月）。
            onTap: () => setState(() => _selectedMonth = null),
            child: Text(
              '${month.year}年${month.month}月',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ForestNeutral.textPrimary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right,
                size: 20, color: ForestNeutral.textPrimary),
            splashRadius: 18,
            onPressed: () => setState(() => _selectedMonth =
                DateTime(month.year, month.month + 1, 1)),
          ),
        ],
      );

  // ── 节头：账单明细 + 按时间/按金额 切换 ───────────────
  Widget _buildSectionBar() {
    final bool byTime = _sortMode == _SortMode.time;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 6),
      child: Row(
        children: <Widget>[
          const Text(
            '账单明细',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: ForestNeutral.textPrimary,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _sortMode =
                byTime ? _SortMode.amount : _SortMode.time),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: ForestGreen.soft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    byTime ? '按时间' : '按金额',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ForestGreen.deep,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    byTime ? Icons.arrow_downward : Icons.sort,
                    size: 13,
                    color: ForestGreen.deep,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 按天分组（filtered 已按当前排序排好） ────────────
  Widget _buildDayGroups(List<Transaction> list) {
    final Map<String, List<Transaction>> groups =
        <String, List<Transaction>>{};
    for (final Transaction t in list) {
      final DateTime day = DateTime.fromMillisecondsSinceEpoch(
        t.occurredAt,
        isUtc: true,
      ).toLocal();
      final String key = DateFormat('yyyy-MM-dd').format(day);
      groups.putIfAbsent(key, () => <Transaction>[]).add(t);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 24),
      itemCount: groups.length,
      itemBuilder: (BuildContext context, int index) {
        final String key = groups.keys.elementAt(index);
        final List<Transaction> items = groups[key]!;
        return _DayGroup(
          day: DateFormat('yyyy-MM-dd').parse(key),
          items: items,
        );
      },
    );
  }
}

/// 单日分组：天头（日期 + 今天/星期X + 小圆环）+ 当日收支合计 + 账单行。
class _DayGroup extends StatelessWidget {
  const _DayGroup({required this.day, required this.items});

  final DateTime day;
  final List<Transaction> items;

  static const List<String> _weekLabels = <String>[
    '星期一',
    '星期二',
    '星期三',
    '星期四',
    '星期五',
    '星期六',
    '星期日',
  ];

  String get _dayLabel {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime target = DateTime(day.year, day.month, day.day);
    final int diff = today.difference(target).inDays;
    if (diff == 0) return 'M月d日 今天'.replaceFirst('M月d日', _md);
    if (diff == 1) return 'M月d日 昨天'.replaceFirst('M月d日', _md);
    return '$_md ${_weekLabels[day.weekday - 1]}';
  }

  String get _md => DateFormat('M月d日').format(day);

  String get _totalLabel {
    int expense = 0;
    int income = 0;
    for (final Transaction t in items) {
      if (t.type == TxnType.expense) {
        expense += t.amountMinor;
      } else if (t.type == TxnType.income) {
        income += t.amountMinor;
      }
    }
    if (expense > 0 && income > 0) {
      return '支:${Money.fromMinor(expense).format()} '
          '收:${Money.fromMinor(income).format()}';
    }
    if (expense > 0) return '支:${Money.fromMinor(expense).format()}';
    if (income > 0) return '收:${Money.fromMinor(income).format()}';
    return '收支:0';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
            child: Row(
              children: <Widget>[
                Text(
                  _dayLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ForestNeutral.textPrimary,
                  ),
                ),
                const SizedBox(width: 5),
                const Icon(Icons.autorenew, size: 14, color: ForestGreen.deep),
                const Spacer(),
                Text(
                  _totalLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: <Widget>[
                for (int i = 0; i < items.length; i++) ...<Widget>[
                  if (i > 0)
                    Container(
                      height: 0.6,
                      margin: const EdgeInsets.only(left: 52),
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  TransactionTile(
                    transaction: items[i],
                    onTap: () =>
                        TransactionDetailSheet.show(context, items[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
