import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_dimens.dart';
import '../../core/theme/forest_design_tokens.dart';
import '../../core/utils/date_utils.dart';

/// 森林手账「日期 + 时间」底部半窗选择器（ForestSage 设计稿落地版）。
///
/// 交互流程（与设计稿 dtp-sheet-V3-floating-seal 一致）：
/// 1. 顶部悬浮「鼠尾草渐变签章卡」：左侧大号日期 + 年份 + 时/分分段钮；
///    右侧内嵌「表盘拨号」设置小时 / 分钟（拖拽表盘或点中心切换调节单位）。
/// 2. 快选胶囊：今天 / 昨天 / 前天 / 此刻。
/// 3. 日历卡：固定 6 行（42 格）高度，弹窗不随月份天数变化；点「年月」展开
///    年份面板（向下弹出覆盖日历，2000 为基准每页 20 年，箭头翻页）。
/// 4. 底部「确认 Confirm」返回一个同时带日期与时间的 [DateTime]；
///    左上角关闭按钮返回 `null`。
///
/// 用法（与原 [DatePickerSheet] 完全兼容）：
/// ```dart
/// final DateTime? picked = await DateTimePickerSheet.show(
///   context,
///   initialDate: DateTime.now(),
/// );
/// ```
class DateTimePickerSheet {
  DateTimePickerSheet._();

  /// 弹出底部日期时间选择器。
  ///
  /// - [initialDate]：默认选中的日期时间。
  /// - [firstDate] / [lastDate]：可选范围（含）。
  /// - [showTime]：为 `false` 时仅选日期（隐藏表盘，确认时时间归零）。
  static Future<DateTime?> show(
    BuildContext context, {
    required DateTime initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
    String currentTimeLabel = '当前时间',
    bool showTime = true,
  }) async {
    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ForestBg.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(ForestRadius.xl)),
      ),
      builder: (BuildContext ctx) => _DateTimePickerSheetBody(
        initialDate: initialDate,
        firstDate: firstDate ?? DateTime(2000),
        lastDate: lastDate ?? DateTime(2100),
        showTime: showTime,
      ),
    );
  }
}

class _DateTimePickerSheetBody extends StatefulWidget {
  const _DateTimePickerSheetBody({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.showTime,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final bool showTime;

  @override
  State<_DateTimePickerSheetBody> createState() =>
      _DateTimePickerSheetBodyState();
}

class _DateTimePickerSheetBodyState extends State<_DateTimePickerSheetBody> {
  late DateTime _selected;
  late DateTime _displayedMonth;
  bool _isYearPickerOpen = false;

  /// 表盘当前调节的单位：true = 小时，false = 分钟（默认调分钟）。
  bool _isHourMode = false;

  /// 「此刻 Now」是否处于点亮状态：点「此刻」置 true，任何手动改动熄灭。
  bool _nowPinned = false;

  /// 年份面板分页游标（2000 为基准，每页 20 年）。
  late int _yearPageStart;

  bool _heroFloat = false;
  late final ScrollController _scrollController;

  static const List<String> _weekCN = <String>[
    '周日',
    '周一',
    '周二',
    '周三',
    '周四',
    '周五',
    '周六',
  ];

  @override
  void initState() {
    super.initState();
    final DateTime now = _localNow();
    final DateTime initialLocalTime = widget.initialDate.toLocal();
    // 若调用方只给了日期（时间为 00:00:00.000），默认把 time 部分设为当前本地时间，
    // 避免签章卡显示「00:00」，而是显示「现在时间」。
    final bool hasNoTime = widget.initialDate.hour == 0 &&
        widget.initialDate.minute == 0 &&
        widget.initialDate.second == 0 &&
        widget.initialDate.millisecond == 0 &&
        widget.initialDate.microsecond == 0;
    _selected = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
      hasNoTime ? now.hour : initialLocalTime.hour,
      hasNoTime ? now.minute : initialLocalTime.minute,
      hasNoTime ? 0 : initialLocalTime.second,
      hasNoTime ? 0 : initialLocalTime.millisecond,
      hasNoTime ? 0 : initialLocalTime.microsecond,
    );
    _displayedMonth = DateTime(_selected.year, _selected.month);
    _yearPageStart = _pageOf(_selected.year);
    // 打开时传入的就是「现在」（同分钟内）→ 直要点亮「此刻 Now」。
    _nowPinned = _selected.year == now.year &&
        _selected.month == now.month &&
        _selected.day == now.day &&
        _selected.hour == now.hour &&
        _selected.minute == now.minute;

    _scrollController = ScrollController()
      ..addListener(() {
        final bool f = _scrollController.offset > 4;
        if (f != _heroFloat) {
          setState(() => _heroFloat = f);
        }
      });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ---- 范围判断 ----

  bool _isMonthAllowed(DateTime month) {
    final DateTime first =
        DateTime(widget.firstDate.year, widget.firstDate.month);
    final DateTime last = DateTime(widget.lastDate.year, widget.lastDate.month);
    return !month.isBefore(first) && !month.isAfter(last);
  }

  bool _isDayAllowed(DateTime day) =>
      !day.isBefore(widget.firstDate) && !day.isAfter(widget.lastDate);

  // ---- 年份分页（2000 基准，每页 20 年）----

  int _pageOf(int year) => 2000 + ((year - 2000) ~/ 20) * 20;

  // ---- 日历操作 ----

  void _previousMonth() {
    final DateTime candidate = DateTime(
      _displayedMonth.year,
      _displayedMonth.month - 1,
    );
    if (_isMonthAllowed(candidate)) {
      setState(() => _displayedMonth = candidate);
    }
  }

  void _nextMonth() {
    final DateTime candidate = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + 1,
    );
    if (_isMonthAllowed(candidate)) {
      setState(() => _displayedMonth = candidate);
    }
  }

  void _selectDay(int day) {
    setState(() {
      _nowPinned = false;
      _selected = DateTime(
        _displayedMonth.year,
        _displayedMonth.month,
        day,
        _selected.hour,
        _selected.minute,
      );
    });
  }

  /// 选中年份：写回 _displayedMonth（保持月份），面板保持展开，日历实时跟随。
  void _selectYear(int year) {
    final DateTime candidate = DateTime(year, _displayedMonth.month);
    if (_isMonthAllowed(candidate)) {
      setState(() => _displayedMonth = candidate);
    }
  }

  void _toggleYearPicker() {
    setState(() {
      _isYearPickerOpen = !_isYearPickerOpen;
      if (_isYearPickerOpen) {
        _yearPageStart = _pageOf(_selected.year);
      }
    });
  }

  /// 年份面板展开时：左右箭头翻页（±20 年），不改所选年月；
  /// 收起时：左右箭头切月。
  void _shiftArrow(int n) {
    if (_isYearPickerOpen) {
      final int minP = _pageOf(widget.firstDate.year);
      final int maxP = _pageOf(widget.lastDate.year);
      setState(() {
        _yearPageStart = (_yearPageStart + n * 20).clamp(minP, maxP);
      });
      return;
    }
    if (n < 0) {
      _previousMonth();
    } else {
      _nextMonth();
    }
  }

  // ---- 时间操作 ----

  void _setHour(int v) => setState(() {
        _nowPinned = false;
        _selected = DateTime(
          _selected.year,
          _selected.month,
          _selected.day,
          v,
          _selected.minute,
        );
      });

  void _setMinute(int v) => setState(() {
        _nowPinned = false;
        _selected = DateTime(
          _selected.year,
          _selected.month,
          _selected.day,
          _selected.hour,
          v,
        );
      });

  void _toggleMode() => setState(() => _isHourMode = !_isHourMode);

  // ---- 快选 ----

  void _quickDate(int offset) {
    final DateTime now = _localNow();
    final DateTime t = DateTime(now.year, now.month, now.day + offset);
    setState(() {
      // 快选（今天/昨天/前天）只改日期、保留所选时间 → 不再等于「此刻」。
      _nowPinned = false;
      _selected = DateTime(
        t.year,
        t.month,
        t.day,
        _selected.hour,
        _selected.minute,
      );
      _displayedMonth = DateTime(t.year, t.month);
    });
    _syncYearPanel();
  }

  void _jumpToCurrent() {
    final DateTime now = _localNow();
    setState(() {
      _selected = now;
      _displayedMonth = DateTime(now.year, now.month);
      _nowPinned = true;
    });
    _syncYearPanel();
  }

  /// 快选跳转后：若年份面板展开，翻回包含当前年份的页（高亮立即可见）。
  void _syncYearPanel() {
    if (_isYearPickerOpen) {
      setState(() => _yearPageStart = _pageOf(_selected.year));
    }
  }

  // ---- 工具 ----

  String _weekdayCN(DateTime d) => _weekCN[d.weekday % 7];

  /// 获取当前本地时间（GMT+8 兜底，保证中国用户看到正确的「现在时间」）。
  DateTime _localNow() => localNow();

  int _dayDiffFromToday() {
    final DateTime now = _localNow();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime sel = DateTime(_selected.year, _selected.month, _selected.day);
    return sel.difference(today).inDays;
  }

  bool _isNowSelected() => _nowPinned;

  // ---- 视图切换 ----

  void _onConfirm() {
    if (widget.showTime) {
      Navigator.of(context).pop(_selected);
    } else {
      Navigator.of(context)
          .pop(DateTime(_selected.year, _selected.month, _selected.day));
    }
  }

  // ---- 日期矩阵（固定 42 格 = 6 行，弹窗高度不随月份天数变化）----

  List<int?> _buildDaysMatrix() {
    final int daysInMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + 1,
      0,
    ).day;
    final DateTime firstDay = DateTime(
      _displayedMonth.year,
      _displayedMonth.month,
      1,
    );
    final int leading = firstDay.weekday % 7; // 周日为首列
    final List<int?> days = <int?>[
      for (int i = 0; i < leading; i++) null,
      for (int i = 1; i <= daysInMonth; i++) i,
    ];
    while (days.length < 42) {
      days.add(null);
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final double maxH = MediaQuery.of(context).size.height * 0.92;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Container(
          color: ForestBg.paper,
          child: Column(
            // 贴合内容高度：内容不足 92vh 时不留大空隙（对照设计稿）；
            // 超出时 Flexible 内的滚动区生效，仍可整体滚动。
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _buildHandle(),
              _buildHeader(),
              _buildHeroSeal(),
              Flexible(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Column(
                    children: <Widget>[
                      _buildQuickChips(),
                      _buildCalendarCard(),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              ),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  // ---- 顶部拖拽把手 ----

  Widget _buildHandle() => Container(
        margin: const EdgeInsets.only(top: 10),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: ForestNeutral.hairline,
          borderRadius: BorderRadius.circular(ForestRadius.pill),
        ),
      );

  // ---- Header（关闭 / DATE & TIME）----

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.spaceLg,
          AppDimens.spaceMd,
          AppDimens.spaceLg,
          4,
        ),
        child: Row(
          children: <Widget>[
            _CloseButton(onPressed: () => Navigator.of(context).pop()),
            const SizedBox(width: 10),
            const Text(
              'DATE & TIME',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: ForestGreen.deep,
                letterSpacing: 4,
              ),
            ),
          ],
        ),
      );

  // ---- 悬浮签章卡（鼠尾草渐变，内嵌表盘拨号）----

  Widget _buildHeroSeal() => Container(
        margin: const EdgeInsets.fromLTRB(18, 8, 18, 2),
        padding: const EdgeInsets.fromLTRB(18, 15, 18, 15),
        decoration: BoxDecoration(
          gradient: ForestGradients.sage,
          borderRadius: BorderRadius.circular(20),
          boxShadow: _heroFloat ? ForestElevation.float : ForestElevation.card,
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              right: -28,
              top: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x24FFFFFF),
                ),
              ),
            ),
            Positioned(
              right: 26,
              bottom: -46,
              child: Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x1AFFFFFF),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'RECORD AT',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 3,
                    color: Color(0xD9FFFFFF),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: <Widget>[
                              Text(
                                '${_selected.month}月${_selected.day}日 ${_weekdayCN(_selected)}',
                                style: const TextStyle(
                                  fontSize: 27,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(width: 9),
                              Text(
                                '${_selected.year}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xEBFFFFFF),
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                          if (widget.showTime) ...<Widget>[
                            const SizedBox(height: 16),
                            _buildHeroSeg(),
                          ],
                        ],
                      ),
                    ),
                    if (widget.showTime) _buildHeroDial(),
                  ],
                ),
              ],
            ),
          ],
        ),
      );

  /// 时 / 分 分段钮（签章卡内：选中态改白底深绿字）。
  Widget _buildHeroSeg() => Container(
        height: 36,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0x29FFFFFF),
          borderRadius: BorderRadius.circular(ForestRadius.pill),
          border: Border.all(color: const Color(0x59FFFFFF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _heroSegBtn('时 Hour', true),
            _heroSegBtn('分 Min', false),
          ],
        ),
      );

  Widget _heroSegBtn(String label, bool isHour) {
    final bool on = _isHourMode == isHour;
    return InkWell(
      onTap: () => setState(() => _isHourMode = isHour),
      borderRadius: BorderRadius.circular(ForestRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: on ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(ForestRadius.pill),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: on ? ForestGreen.deep : const Color(0xD9FFFFFF),
          ),
        ),
      ),
    );
  }

  /// 签章卡内嵌表盘拨号（浅色化配色，中心显示 hh:mm + 单位）。
  Widget _buildHeroDial() => _TimeDial(
        seal: true,
        hourMode: _isHourMode,
        hour: _selected.hour,
        minute: _selected.minute,
        onHourChanged: _setHour,
        onMinuteChanged: _setMinute,
        onToggleMode: _toggleMode,
      );

  // ---- 快选胶囊 ----

  Widget _buildQuickChips() {
    final int diff = _dayDiffFromToday();
    final bool nowOn = _isNowSelected();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 2),
      child: Row(
        children: <Widget>[
          _quickChip('今天 Today', diff == 0 && !nowOn, () => _quickDate(0)),
          const SizedBox(width: 8),
          _quickChip('昨天 Yda', diff == -1, () => _quickDate(-1)),
          const SizedBox(width: 8),
          _quickChip('前天 −2d', diff == -2, () => _quickDate(-2)),
          const SizedBox(width: 8),
          _quickChip('此刻 Now', nowOn, _jumpToCurrent),
        ],
      ),
    );
  }

  Widget _quickChip(String label, bool on, VoidCallback onTap) => Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: on ? ForestGradients.sage : null,
              color: on ? null : ForestSurface.card,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: on ? Colors.transparent : ForestNeutral.hairline,
              ),
              boxShadow: on ? ForestElevation.sm : ForestElevation.flat,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: on ? Colors.white : ForestNeutral.textPrimary,
              ),
            ),
          ),
        ),
      );

  // ---- 日历卡（年份面板向下弹出覆盖）----

  Widget _buildCalendarCard() {
    final bool canPrev = _isMonthAllowed(
      DateTime(_displayedMonth.year, _displayedMonth.month - 1),
    );
    final bool canNext = _isMonthAllowed(
      DateTime(_displayedMonth.year, _displayedMonth.month + 1),
    );
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 10, 18, 0),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      decoration: BoxDecoration(
        color: ForestSurface.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ForestNeutral.hairline),
      ),
      child: Stack(
        children: <Widget>[
          Column(
            children: <Widget>[
              _buildMonthBar(canPrev, canNext),
              const _WeekdayRow(),
              _buildDayGrid(),
            ],
          ),
          Positioned(
            top: 44,
            left: 8,
            right: 8,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: _isYearPickerOpen ? 236 : 0,
              decoration: BoxDecoration(
                color: ForestSurface.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isYearPickerOpen
                      ? ForestNeutral.hairline
                      : Colors.transparent,
                ),
                boxShadow: _isYearPickerOpen
                    ? ForestElevation.card
                    : ForestElevation.flat,
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildYearGrid(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthBar(bool canPrev, bool canNext) => SizedBox(
        height: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: <Widget>[
              InkWell(
                onTap: _toggleYearPicker,
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceXs,
                    vertical: AppDimens.spaceXs,
                  ),
                  child: Row(
                    children: <Widget>[
                      Text(
                        DateFormat('yyyy年M月').format(_displayedMonth),
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: ForestNeutral.deepInk,
                        ),
                      ),
                      const SizedBox(width: AppDimens.spaceXs),
                      Icon(
                        Icons.expand_more,
                        color: ForestNeutral.textSecondary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              _Arrow(
                icon: Icons.chevron_left,
                enabled: _isYearPickerOpen || canPrev,
                onPressed: () => _shiftArrow(-1),
              ),
              _Arrow(
                icon: Icons.chevron_right,
                enabled: _isYearPickerOpen || canNext,
                onPressed: () => _shiftArrow(1),
              ),
            ],
          ),
        ),
      );

  Widget _buildDayGrid() {
    final List<int?> days = _buildDaysMatrix();
    final DateTime today = _localNow();
    final DateTime todayOnly = DateTime(today.year, today.month, today.day);
    final DateTime selectedDayOnly = DateTime(
      _selected.year,
      _selected.month,
      _selected.day,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 7,
        childAspectRatio: 1,
        children: days.map((int? day) {
          if (day == null) return const SizedBox.shrink();
          final DateTime date = DateTime(
            _displayedMonth.year,
            _displayedMonth.month,
            day,
          );
          final bool isSelected = date == selectedDayOnly;
          final bool isToday = date == todayOnly;
          final bool isAfterToday = date.isAfter(todayOnly);
          final bool isAllowed = _isDayAllowed(date);
          final bool isMuted =
              !isSelected && (isAfterToday || !isAllowed);
          return _DayCell(
            day: day,
            isSelected: isSelected,
            isToday: isToday,
            isMuted: isMuted,
            isEnabled: isAllowed,
            onTap: () => _selectDay(day),
          );
        }).toList(growable: false),
      ),
    );
  }

  Widget _buildYearGrid() => GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.3,
        padding: const EdgeInsets.all(8),
        children: <Widget>[
          for (int i = 0; i < 20; i++) _yearCell(_yearPageStart + i),
        ],
      );

  Widget _yearCell(int y) {
    final bool inRange = y >= widget.firstDate.year && y <= widget.lastDate.year;
    final bool selected = y == _displayedMonth.year;
    return GestureDetector(
      onTap: inRange
          ? () => _selectYear(y)
          : null,
      // 双击年份：选中并收起面板，返回月份（日历）视图。
      onDoubleTap: inRange
          ? () {
              _selectYear(y);
              if (_isYearPickerOpen) _toggleYearPicker();
            }
          : null,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? null : (inRange ? ForestBg.sunken : Colors.transparent),
          gradient: selected ? ForestGradients.sage : null,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: selected ? Colors.transparent : ForestNeutral.hairline,
          ),
        ),
        child: Text(
          '$y',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected
                ? Colors.white
                : (inRange
                    ? ForestNeutral.textPrimary
                    : ForestNeutral.textTertiary),
          ),
        ),
      ),
    );
  }

  // ---- 底部确认 ----

  Widget _buildFooter() => Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
        decoration: BoxDecoration(
          color: ForestBg.paper,
          border: Border(top: BorderSide(color: ForestNeutral.hairline)),
        ),
        child: Column(
          children: <Widget>[
            _ConfirmButton(onPressed: _onConfirm),
            const SizedBox(height: 14),
          ],
        ),
      );
}

/// 表盘拨号：拖动设置小时 / 分钟，中心显示当前调节单位。
/// [seal]=true 时配色浅色化（用于签章卡内）。
class _TimeDial extends StatelessWidget {
  _TimeDial({
    required this.hourMode,
    required this.hour,
    required this.minute,
    required this.onHourChanged,
    required this.onMinuteChanged,
    required this.onToggleMode,
    this.seal = false,
  });

  final bool hourMode;
  final int hour;
  final int minute;
  final ValueChanged<int> onHourChanged;
  final ValueChanged<int> onMinuteChanged;
  final VoidCallback onToggleMode;
  final bool seal;

  double get _size => seal ? 112 : 172;
  final GlobalKey _key = GlobalKey();

  void _handle(Offset global, bool allowToggle) {
    final RenderBox? box =
        _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final Offset p = box.globalToLocal(global);
    final Offset c = box.size.center(Offset.zero);
    final double dx = p.dx - c.dx;
    final double dy = p.dy - c.dy;
    // 点中心区域（直径 18% 半径内）切换时 / 分。
    if (allowToggle && math.sqrt(dx * dx + dy * dy) < box.size.width * 0.18) {
      onToggleMode();
      return;
    }
    double deg = math.atan2(dx, -dy) * 180 / math.pi;
    if (deg < 0) deg += 360;
    final int count = hourMode ? 24 : 60;
    final int val = (deg / (360 / count)).round() % count;
    if (hourMode) {
      onHourChanged(val);
    } else {
      onMinuteChanged(val);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: GestureDetector(
        key: _key,
        behavior: HitTestBehavior.opaque,
        onPanStart: (DragStartDetails d) => _handle(d.globalPosition, false),
        onPanUpdate: (DragUpdateDetails d) => _handle(d.globalPosition, false),
        onTapDown: (TapDownDetails d) => _handle(d.globalPosition, true),
        child: Stack(
          children: <Widget>[
            CustomPaint(
              size: Size(_size, _size),
              painter: _DialPainter(
                hourMode: hourMode,
                hour: hour,
                minute: minute,
                seal: seal,
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    '${hour.toString().padLeft(2, '0')}:'
                    '${minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    hourMode ? '时 HOUR' : '分 MIN',
                    style: const TextStyle(
                      fontSize: 8,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                      color: Color(0xD9FFFFFF),
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
}

/// 表盘拨号绘制：外圈刻度 + 进度弧 + 可拖拽拨针。
class _DialPainter extends CustomPainter {
  const _DialPainter({
    required this.hourMode,
    required this.hour,
    required this.minute,
    this.seal = false,
  });

  final bool hourMode;
  final int hour;
  final int minute;
  final bool seal;

  static const Color _sage1 = Color(0xFF93BF9A);
  static const Color _sage2 = Color(0xFF5F9A6E);
  static const Color _sageSolid = Color(0xFF5F9A6E);

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = Offset(size.width / 2, size.height / 2);
    final double r = size.width / 2 - 10;

    // 外圈轨道
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = seal ? const Color(0x59FFFFFF) : ForestNeutral.hairline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // 刻度（每 5 格主刻度）
    for (int i = 0; i < 60; i++) {
      final double a = i * 2 * math.pi / 60 - math.pi / 2;
      final bool major = i % 5 == 0;
      final double r2 = r - 3;
      final double r1 = major ? r - 14 : r - 9;
      canvas.drawLine(
        Offset(c.dx + r1 * math.cos(a), c.dy + r1 * math.sin(a)),
        Offset(c.dx + r2 * math.cos(a), c.dy + r2 * math.sin(a)),
        Paint()
          ..color = seal
              ? (major ? const Color(0xE6FFFFFF) : const Color(0x73FFFFFF))
              : (major ? ForestNeutral.textTertiary : ForestNeutral.hairline)
          ..strokeWidth = major ? 2 : 1
          ..strokeCap = StrokeCap.round,
      );
    }

    // 进度弧
    final double frac = hourMode ? hour / 24 : minute / 60;
    final Rect arcRect = Rect.fromCircle(center: c, radius: r - 6);
    if (seal) {
      canvas.drawArc(
        arcRect,
        -math.pi / 2,
        frac * 2 * math.pi,
        false,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round,
      );
    } else {
      canvas.drawArc(
        arcRect,
        -math.pi / 2,
        frac * 2 * math.pi,
        false,
        Paint()
          ..shader = const SweepGradient(
            center: Alignment.center,
            startAngle: -math.pi / 2,
            endAngle: 3 * math.pi / 2,
            colors: <Color>[_sage1, _sage2],
          ).createShader(arcRect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round,
      );
    }

    // 拨针
    final double ka = frac * 2 * math.pi - math.pi / 2;
    final double kr = r - 6;
    final Offset k = Offset(c.dx + kr * math.cos(ka), c.dy + kr * math.sin(ka));
    canvas.drawCircle(
      k,
      9,
      Paint()..color = seal ? const Color(0xFFFFFCF5) : ForestGreen.deep,
    );
    canvas.drawCircle(
      k,
      9,
      Paint()
        ..color = seal ? ForestGreen.deep : Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) =>
      old.hourMode != hourMode ||
      old.hour != hour ||
      old.minute != minute ||
      old.seal != seal;
}

// ---- 小组件 ----

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: ForestSurface.card,
          shape: BoxShape.circle,
          border: Border.all(color: ForestNeutral.hairline),
        ),
        child: IconButton(
          icon: const Icon(Icons.close, size: 18, color: ForestNeutral.deepInk),
          padding: EdgeInsets.zero,
          onPressed: onPressed,
        ),
      );
}

class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Container(
        height: 48,
        decoration: BoxDecoration(
          gradient: ForestGradients.sage,
          borderRadius: BorderRadius.circular(16),
          boxShadow: ForestElevation.sm,
        ),
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text(
            '确认 Confirm',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
        ),
      );
}

class _Arrow extends StatelessWidget {
  const _Arrow({
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Container(
        width: 30,
        height: 30,
        margin: const EdgeInsets.only(left: 6),
        decoration: BoxDecoration(
          color: ForestBg.sunken,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ForestNeutral.hairline),
        ),
        child: IconButton(
          icon: Icon(icon, size: 16, color: ForestNeutral.deepInk),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          onPressed: enabled ? onPressed : null,
        ),
      );
}

class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow();

  static const List<String> _labels = <String>[
    '日',
    '一',
    '二',
    '三',
    '四',
    '五',
    '六',
  ];

  static const Color _sageAccent = Color(0xFF5F9A6E);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 4, 2, 0),
        child: Row(
          children: _labels
              .map(
                (String label) => Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: (label == '日' || label == '六')
                            ? _sageAccent
                            : ForestNeutral.textTertiary,
                      ),
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        ),
      );
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isSelected,
    required this.isToday,
    required this.isMuted,
    required this.isEnabled,
    required this.onTap,
  });

  final int day;
  final bool isSelected;
  final bool isToday;
  final bool isMuted;
  final bool isEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color textColor = isSelected
        ? Colors.white
        : isMuted
            ? ForestNeutral.textTertiary
            : (isToday ? ForestGreen.deep : ForestNeutral.textPrimary);
    return Center(
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: isSelected ? ForestGradients.sage : null,
            color: isSelected
                ? null
                : isToday
                    ? ForestGreen.soft
                    : Colors.transparent,
            shape: BoxShape.circle,
            border: !isSelected && isToday
                ? Border.all(color: ForestGreen.softBorder)
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Text(
                '$day',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected
                      ? FontWeight.w800
                      : isToday
                          ? FontWeight.w700
                          : FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 兼容旧名 [DatePickerSheet]。
///
/// 原 `add_installment_page.dart` 等调用方无需改动。
class DatePickerSheet {
  DatePickerSheet._();

  static Future<DateTime?> show(
    BuildContext context, {
    required DateTime initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
    String currentTimeLabel = '当前时间',
    bool showTime = true,
  }) async =>
      DateTimePickerSheet.show(
        context,
        initialDate: initialDate,
        firstDate: firstDate,
        lastDate: lastDate,
        currentTimeLabel: currentTimeLabel,
        showTime: showTime,
      );
}
