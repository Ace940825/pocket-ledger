import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/forest_design_tokens.dart';
import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../routing/app_router.dart';
import '../../../shared/models/money.dart';
import '../../../shared/widgets/calendar_sheet.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/line_icon_map.dart';
import '../../../shared/widgets/summary_bar.dart';
import '../../../theme/app_theme.dart';
import '../../ledger/presentation/transaction_detail_sheet.dart';
import '../../ledger/presentation/widgets/transaction_tile.dart';
import '../../ledger/presentation/widgets/txn_slidable.dart';
import '../../ledger/providers/ledger_providers.dart';
import '../../record/record_tab.dart';

/// 退款记录页（「我的 → 退款」入口）。
///
/// 罗列当前账本下全部退款流水（sourceModule = refund），按天分组、时间倒序；
/// 头部「周期筛选行」（周/月/年/自定义，默认全部）+ 合计笔数与金额，
/// 右上「记退款」直达记一笔退款 Tab；
/// 行复用 [TransactionTile]（左滑迁移/编辑/删除/复制），点击进流水明细。
class RefundPage extends ConsumerStatefulWidget {
  const RefundPage({super.key});

  @override
  ConsumerState<RefundPage> createState() => _RefundPageState();
}

class _RefundPageState extends ConsumerState<RefundPage> {
  /// 周期筛选；默认当月，进入页面即显示本月退款。
  LedgerPeriod? _period = LedgerPeriod.monthOf(DateTime.now());

  /// 排序方式：false = 最近时间在前（默认），true = 金额从大到小。
  bool _sortByAmount = false;

  @override
  Widget build(BuildContext context) {
    final List<Transaction> all =
        ref.watch(bookAllTransactionsProvider).valueOrNull ??
            const <Transaction>[];
    Iterable<Transaction> refunds =
        all.where((Transaction t) => t.sourceModule == SourceModule.refund);
    if (_period != null) {
      // 与账单清理页同口径：周期本地零点毫秒与 occurredAt 同源可比。
      final int startMs = _period!.start.millisecondsSinceEpoch;
      final int endMs = _period!.end.millisecondsSinceEpoch;
      refunds = refunds.where(
        (Transaction t) => t.occurredAt >= startMs && t.occurredAt < endMs,
      );
    }
    final List<Transaction> list = refunds.toList()
      ..sort((Transaction a, Transaction b) {
        if (_sortByAmount) {
          // 实退金额（原额 − 优惠）从大到小，同额按时间倒序兜底。
          final int am = a.amountMinor - a.discountMinor;
          final int bm = b.amountMinor - b.discountMinor;
          if (bm != am) return bm.compareTo(am);
        }
        return b.occurredAt.compareTo(a.occurredAt);
      });

    final int total = list.fold<int>(
      0,
      (int m, Transaction t) => m + t.amountMinor - t.discountMinor,
    );

    // 按天分组（已倒序，LinkedHashMap 保持首遇顺序=最新一天在前）。
    final Map<String, List<Transaction>> groups = <String, List<Transaction>>{};
    for (final Transaction t in list) {
      final DateTime day = DateTime.fromMillisecondsSinceEpoch(
        t.occurredAt,
        isUtc: true,
      ).toLocal();
      final String key = DateFormat('yyyy-MM-dd').format(day);
      groups.putIfAbsent(key, () => <Transaction>[]).add(t);
    }

    return Scaffold(
      backgroundColor: context.colors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _buildHeader(context),
            _buildPeriodRow(context),
            _buildSummaryBar(context, list.length, total),
            Expanded(
              child: list.isEmpty
                  ? EmptyState(
                      message: _period == null
                          ? '暂无退款记录\n记一笔 → 退款 可新增'
                          : '当前周期暂无退款记录',
                      icon: Icons.assignment_return_outlined,
                    )
                  : _buildDayGroups(context, groups),
            ),
          ],
        ),
      ),
    );
  }

  // ── 头部：‹ 返回 + 居中标题 ────────────────────────────
  Widget _buildHeader(BuildContext context) {
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
                  Icons.arrow_back_ios_new,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
          // 自定义头部无 AppBar 承载，直接复用主题 appBarTheme.titleTextStyle，
          // 与全站标题（17pt w800 居中）保持一致。
          Center(
            child: Text(
              '退款记录',
              style: Theme.of(context).appBarTheme.titleTextStyle,
            ),
          ),
        ],
      ),
    );
  }

  // ── 操作行：「全部/周期标签 ˅」居左 + 排序切换、「记退款」居右 ──
  Widget _buildPeriodRow(BuildContext context) {
    final bool filtered = _period != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
      child: Row(
        children: <Widget>[
          // 周期标签可能很长（自定义区间），Expanded 强制占满剩余宽度
          // （内容左对齐、过长省略），把右侧胶囊推到屏幕右缘。
          // 注意：不能用 Flexible(loose)——loose 不占用剩余空间，
          // 剩余宽度会整段空在右侧，胶囊永远贴不了右。
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
                        filtered ? _period!.label : '全部',
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
            onTap: () => setState(() => _sortByAmount = !_sortByAmount),
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
                    _sortByAmount
                        ? Icons.payments_outlined
                        : Icons.schedule_rounded,
                    size: 14,
                    color: ForestGreen.deep,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    _sortByAmount ? '金额' : '时间',
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
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => context.push(Routes.record, extra: RecordTab.refund),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: ForestGreen.soft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  LineGlyph(Icons.add, size: 14, color: ForestGreen.deep),
                  SizedBox(width: 3),
                  Text(
                    '记退款',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ForestGreen.deep,
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

  /// 周期切换：共享日历组件（CalendarSheet 纯周期模式，与账单清理页同款），
  /// 支持周/月/年/自定义四种粒度，确认后整段区间生效。
  Future<void> _pickPeriod() async {
    final CalendarPeriodMode cm = switch (_period?.mode) {
      LedgerPeriodMode.week => CalendarPeriodMode.week,
      LedgerPeriodMode.month => CalendarPeriodMode.month,
      LedgerPeriodMode.year => CalendarPeriodMode.year,
      LedgerPeriodMode.custom => CalendarPeriodMode.custom,
      null => CalendarPeriodMode.month,
    };
    final CalendarSelection? r = await CalendarSheet.show(
      context,
      mode: CalendarSheetMode.day,
      showDayView: false,
      headerTitle: '退款周期',
      initialPeriod: _period == null
          ? null
          : CalendarPeriod(cm, _period!.start, _period!.end),
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

  // ── 按天分组列表 ──────────────────────────────────────
  Widget _buildDayGroups(
    BuildContext context,
    Map<String, List<Transaction>> groups,
  ) {
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

/// 单日分组：天头（日期 + 今天/昨天/星期X）+ 当日退款合计 + 退款流水行。
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

  String get _md => DateFormat('M月d日').format(day);

  String get _dayLabel {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime target = DateTime(day.year, day.month, day.day);
    final int diff = today.difference(target).inDays;
    if (diff == 0) return '$_md 今天';
    if (diff == 1) return '$_md 昨天';
    return '$_md ${_weekLabels[day.weekday - 1]}';
  }

  String get _totalLabel {
    final int sum = items.fold<int>(
      0,
      (int m, Transaction t) => m + t.amountMinor - t.discountMinor,
    );
    return '退:${Money.fromMinor(sum).format()}';
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
                const LineGlyph(
                  Icons.assignment_return_outlined,
                  size: 14,
                  color: ForestGreen.deep,
                ),
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
