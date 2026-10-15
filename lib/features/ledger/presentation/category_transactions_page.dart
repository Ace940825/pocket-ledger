import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pocket_ledger/shared/widgets/loading_state.dart';
import 'package:pocket_ledger/shared/widgets/summary_bar.dart';
import 'package:pocket_ledger/theme/app_theme.dart';

import '../../../core/theme/forest_design_tokens.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/calendar_sheet.dart';
import '../../../shared/widgets/line_icon_map.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../providers/ledger_providers.dart';
import 'transaction_detail_sheet.dart';
import 'widgets/transaction_tile.dart';
import 'widgets/txn_slidable.dart';

/// 分类账单页 · 布局与退款记录页同款。
///
/// 头部：圆形 ✕ 关闭 + 居中标题「分类名」（17pt w800 主题标题）；
/// 操作行：左「周期标签 ˅」（点开共享日历，周/月/年/自定义，默认该分类
/// 最近一笔所在月）+ 右「时间 ⇅ / 金额 ⇅」排序胶囊（点一下互换）；
/// 合计条：共 N 笔 · 合计 xx；
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
  /// 周期筛选；null = 自动（取该分类最近一笔所在月）；选定后锁定该周期。
  LedgerPeriod? _period;
  _SortMode _sortMode = _SortMode.time;

  /// 生效周期：已选定用选定值；否则自动取最近一笔所在月（无流水取当月）。
  LedgerPeriod _effectivePeriod(List<Transaction> list) {
    if (_period != null) return _period!;
    DateTime anchor;
    if (list.isEmpty) {
      final DateTime now = DateTime.now();
      anchor = DateTime(now.year, now.month, 1);
    } else {
      int latest = list.fold<int>(
        0,
        (int m, Transaction t) => t.occurredAt > m ? t.occurredAt : m,
      );
      final DateTime d =
          DateTime.fromMillisecondsSinceEpoch(latest, isUtc: true).toLocal();
      anchor = DateTime(d.year, d.month, 1);
    }
    return LedgerPeriod.monthOf(anchor);
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, Category> categories =
        ref.watch(categoryMapProvider).valueOrNull ?? <String, Category>{};
    final Category? category = categories[widget.categoryId];
    final AsyncValue<List<Transaction>> listAsync =
        ref.watch(categoryTransactionsProvider(widget.categoryId));

    final List<Transaction> data =
        listAsync.valueOrNull ?? const <Transaction>[];
    final LedgerPeriod period = _effectivePeriod(data);
    // 与退款页同口径：周期本地零点毫秒与 occurredAt 同源可比。
    final int startMs = period.start.millisecondsSinceEpoch;
    final int endMs = period.end.millisecondsSinceEpoch;
    final List<Transaction> filtered = data.where((Transaction t) {
      return t.occurredAt >= startMs && t.occurredAt < endMs;
    }).toList();
    // 全局排序：按时间倒序，或按实付金额（原额−优惠）倒序。
    if (_sortMode == _SortMode.time) {
      filtered.sort(
        (Transaction a, Transaction b) => b.occurredAt.compareTo(a.occurredAt),
      );
    } else {
      filtered.sort(
        (Transaction a, Transaction b) => (b.amountMinor - b.discountMinor)
            .compareTo(a.amountMinor - a.discountMinor),
      );
    }

    final int count = filtered.length;
    final int totalMinor = filtered.fold<int>(
      0,
      (int m, Transaction t) => m + t.amountMinor - t.discountMinor,
    );
    final String name = category?.name ?? '分类';

    return Scaffold(
      backgroundColor: context.colors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _buildHeader(context, name),
            _buildPeriodRow(context, period),
            _buildSummaryBar(context, count, totalMinor),
            Expanded(
              child: listAsync.when(
                loading: () => const LoadingState(),
                error: (Object e, StackTrace _) => Center(
                  child: Text(
                    '加载失败 $e',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                data: (_) {
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        data.isEmpty ? '该分类下暂无账单' : '该分类 ${period.label} 暂无账单',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
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

  // ── 头部：✕ + 居中标题（分类名，主题标题样式） ────────
  Widget _buildHeader(BuildContext context, String name) {
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
                      color: Theme.of(context)
                          .colorScheme
                          .shadow
                          .withValues(alpha: 0.078),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: LineGlyph(
                  Icons.close,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
          // 自定义头部无 AppBar 承载，直接复用主题 appBarTheme.titleTextStyle，
          // 与全站标题（17pt w800 居中）保持一致。
          Center(
            child:
                Text(name, style: Theme.of(context).appBarTheme.titleTextStyle),
          ),
        ],
      ),
    );
  }

  // ── 操作行：「周期标签 ˅」居左 + 排序胶囊居右（退款页同款） ──
  Widget _buildPeriodRow(BuildContext context, LedgerPeriod period) {
    final bool byAmount = _sortMode == _SortMode.amount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
      child: Row(
        children: <Widget>[
          // 周期标签可能很长（自定义区间），Expanded 强制占满剩余宽度
          // （内容左对齐、过长省略），把右侧胶囊推到屏幕右缘。
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _pickPeriod,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        period.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    LineGlyph(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 排序切换：时间（最近在前）⇄ 金额（从大到小），点一下互换。
          GestureDetector(
            onTap: () => setState(
              () => _sortMode = byAmount ? _SortMode.time : _SortMode.amount,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border.all(color: ForestGreen.softBorder),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  LineGlyph(
                    byAmount ? Icons.payments_outlined : Icons.schedule_rounded,
                    size: 14,
                    color: ForestGreen.deep,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    byAmount ? '金额' : '时间',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ForestGreen.deep,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const LineGlyph(
                    Icons.swap_vert_rounded,
                    size: 14,
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

  /// 周期切换：共享日历组件（CalendarSheet 纯周期模式，与退款页同款），
  /// 支持周/月/年/自定义四种粒度，确认后整段区间生效。
  Future<void> _pickPeriod() async {
    final List<Transaction> data =
        ref.read(categoryTransactionsProvider(widget.categoryId)).valueOrNull ??
            const <Transaction>[];
    final LedgerPeriod current = _effectivePeriod(data);
    final CalendarPeriodMode cm = switch (current.mode) {
      LedgerPeriodMode.week => CalendarPeriodMode.week,
      LedgerPeriodMode.month => CalendarPeriodMode.month,
      LedgerPeriodMode.year => CalendarPeriodMode.year,
      LedgerPeriodMode.custom => CalendarPeriodMode.custom,
    };
    final CalendarSelection? r = await CalendarSheet.show(
      context,
      mode: CalendarSheetMode.day,
      showDayView: false,
      headerTitle: '筛选周期',
      initialPeriod: CalendarPeriod(cm, current.start, current.end),
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year, 12, 31),
      weekStart: CalendarWeekStart.monday,
    );
    if (r is! CalendarPeriod) return;
    final LedgerPeriodMode lm = switch (r.mode) {
      CalendarPeriodMode.week => LedgerPeriodMode.week,
      CalendarPeriodMode.month => LedgerPeriodMode.month,
      CalendarPeriodMode.year => LedgerPeriodMode.year,
      CalendarPeriodMode.custom => LedgerPeriodMode.custom,
    };
    setState(() {
      _period = LedgerPeriod(mode: lm, start: r.start, end: r.end);
    });
  }

  // ── 合计条：共 N 笔 · 合计 xx（统一共享 SummaryBar） ──────
  Widget _buildSummaryBar(BuildContext context, int count, int totalMinor) {
    return SummaryBar(
      count: count,
      totalText: Money.fromMinor(totalMinor).format(),
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 6),
    );
  }

  // ── 按天分组（filtered 已按当前排序排好） ────────────
  Widget _buildDayGroups(List<Transaction> list) {
    final Map<String, List<Transaction>> groups = <String, List<Transaction>>{};
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
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 5),
                const LineGlyph(Icons.autorenew,
                    size: 14, color: ForestGreen.deep),
                const Spacer(),
                Text(
                  _totalLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
            child: TxnSlidableGroup(
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < items.length; i++) ...<Widget>[
                    if (i > 0)
                      Container(
                        height: 0.6,
                        margin: const EdgeInsets.only(left: 52),
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    TxnSlidable(
                      txn: items[i],
                      child: TransactionTile(
                        transaction: items[i],
                        onTap: () =>
                            TransactionDetailSheet.show(context, items[i]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
