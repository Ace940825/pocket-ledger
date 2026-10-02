import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 内嵌月历视图（统一日历组件的「页面内嵌」版，供存钱计划详情等模块
/// 在页面内直接嵌入展示使用；弹窗选择请用 [CalendarSheet.show]）：
///
/// - 大字「yyyy年M月」月份标题（左对齐），**左右滑动可切换月份**（PageView）；
/// - 表头 周一…周日，周一起始；跨月补位日淡灰展示；
/// - 单元格内容由 [dayCellBuilder] 决定（返回 null 用默认数字渲染：
///   未来/今天加粗深色，过去灰字，跨月补位淡灰）；
/// - [onDayTap] 仅本月日期触发（补位日不可点）。
///
/// 可滑动区间由 [firstMonth]/[lastMonth] 决定（null=当前月）；
/// [initialMonth] 缺省取当前月，越界自动夹到区间边缘。
class CalendarMonthView extends StatefulWidget {
  const CalendarMonthView({
    super.key,
    this.firstMonth,
    this.lastMonth,
    this.initialMonth,
    this.dayCellBuilder,
    this.onDayTap,
  });

  /// 可滑动的最早月份（只取年月）。
  final DateTime? firstMonth;

  /// 可滑动的最晚月份（只取年月）。
  final DateTime? lastMonth;

  /// 初始展示月份（只取年月；null=当前月）。
  final DateTime? initialMonth;

  /// 自定义日期格：参数为（上下文、日期、是否本月）；
  /// 返回 null 时用默认数字渲染。只对本月日期与补位日都会调用，
  /// 一般按 `inMonth` 区分：补位日建议返回 null。
  final Widget? Function(BuildContext context, DateTime date, bool inMonth)?
      dayCellBuilder;

  /// 点击本月日期的回调（补位日不触发）。
  final ValueChanged<DateTime>? onDayTap;

  @override
  State<CalendarMonthView> createState() => _CalendarMonthViewState();
}

class _CalendarMonthViewState extends State<CalendarMonthView> {
  late final PageController _pageController;
  late final List<DateTime> _months;
  int _index = 0;

  static DateTime? _norm(DateTime? d) =>
      d == null ? null : DateTime(d.year, d.month, 1);

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    final DateTime nowMonth = DateTime(now.year, now.month, 1);
    final DateTime first = _norm(widget.firstMonth) ?? nowMonth;
    final DateTime last = _norm(widget.lastMonth) ?? nowMonth;
    if (!first.isAfter(last)) {
      _months = <DateTime>[];
      for (DateTime m = first;
          !m.isAfter(last);
          m = DateTime(m.year, m.month + 1, 1)) {
        _months.add(m);
      }
    } else {
      _months = <DateTime>[nowMonth];
    }
    DateTime want = _norm(widget.initialMonth) ?? nowMonth;
    if (want.isBefore(_months.first)) want = _months.first;
    if (want.isAfter(_months.last)) want = _months.last;
    _index = _months.indexOf(want);
    if (_index < 0) _index = 0;
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double spacing = 6;
        final double cellW = constraints.maxWidth / 7;
        final double cellH = cellW / 0.86;
        // PageView 需要固定高度：按最多 6 行月份预留。
        final double pageH = 6 * cellH + 5 * spacing;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              DateFormat('yyyy年M月').format(_months[_index]),
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: pageH,
              child: PageView.builder(
                controller: _pageController,
                itemCount: _months.length,
                onPageChanged: (int i) => setState(() => _index = i),
                itemBuilder: (BuildContext context, int i) =>
                    _monthPage(context, _months[i]),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 单个月份页：表头 + 6 行网格（跨月补位）。
  Widget _monthPage(BuildContext context, DateTime month) {
    final ThemeData theme = Theme.of(context);
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime first = DateTime(month.year, month.month, 1);
    final int daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // 周一 = 1 … 周日 = 7；表头按周一起始。
    final int leading = first.weekday - 1;
    final int prevMonthDays = DateTime(month.year, month.month, 0).day;
    final int trailing = (7 - (leading + daysInMonth) % 7) % 7;

    Widget defaultCell(int day, bool inMonth) {
      final DateTime date = DateTime(month.year, month.month, day);
      final bool isToday = date == today;
      final bool future = date.isAfter(today);
      return Center(
        child: Text(
          '$day',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight:
                inMonth && (future || isToday) ? FontWeight.w700 : FontWeight.w400,
            color: !inMonth
                ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.45)
                : (future || isToday)
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    Widget cell(int day, bool inMonth) {
      final DateTime date = DateTime(month.year, month.month, day);
      final Widget? custom = widget.dayCellBuilder?.call(context, date, inMonth);
      Widget content = custom ?? defaultCell(day, inMonth);
      if (inMonth && widget.onDayTap != null) {
        content = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onDayTap!(date),
          child: content,
        );
      }
      return Padding(padding: const EdgeInsets.all(2), child: content);
    }

    final List<Widget> cells = <Widget>[
      for (final String w in const <String>[
        '周一',
        '周二',
        '周三',
        '周四',
        '周五',
        '周六',
        '周日',
      ])
        Center(
          child: Text(
            w,
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      // 上月尾补位。
      for (int i = leading - 1; i >= 0; i--) cell(prevMonthDays - i, false),
      // 本月。
      for (int day = 1; day <= daysInMonth; day++) cell(day, true),
      // 下月头补位。
      for (int day = 1; day <= trailing; day++) cell(day, false),
    ];

    return GridView.count(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      crossAxisCount: 7,
      mainAxisSpacing: 6,
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 0.86,
      children: cells,
    );
  }
}
