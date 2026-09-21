import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';

/// 时间滚轮中心高亮条颜色（浅灰）。
const Color _wheelHighlight = Color(0xFFE5E5EA);

/// 小青账风格的「日期 + 时间」底部半窗选择器。
///
/// 交互流程：
/// 1. 日历视图：点选日期（绿色圆形高亮）后，点「确认」进入时间视图；
/// 2. 时间视图：滚动「小时 / 分钟」双列滚轮（中心高亮条），点「确认」返回
///    一个同时带日期与时间的 [DateTime]；
/// 3. 左上角关闭按钮返回 `null`；「当前时间」一键跳到此刻。
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
  /// - [showTime]：是否进入时间滚轮视图；为 `false` 时仅选日期并直接返回。
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusLg),
        ),
      ),
      builder: (BuildContext ctx) => _DateTimePickerSheetBody(
        initialDate: initialDate,
        firstDate: firstDate ?? DateTime(2000),
        lastDate: lastDate ?? DateTime(2100),
        currentTimeLabel: currentTimeLabel,
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
    required this.currentTimeLabel,
    required this.showTime,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String currentTimeLabel;
  final bool showTime;

  @override
  State<_DateTimePickerSheetBody> createState() =>
      _DateTimePickerSheetBodyState();
}

class _DateTimePickerSheetBodyState extends State<_DateTimePickerSheetBody> {
  late DateTime _selected;
  late DateTime _displayedMonth;
  bool _isYearPickerOpen = false;
  bool _isTimeView = false;

  late int _activeHour;
  late int _activeMinute;
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;

  /// 年份选择器滚动控制器，展开时自动定位到选中年份。
  late final ScrollController _yearScrollController;

  /// 年份选择器每个年份项的 GlobalKey，用于展开时自动滚动到选中年份。
  late final Map<int, GlobalKey> _yearKeys;

  @override
  void initState() {
    super.initState();
    final DateTime now = _localNow();
    final DateTime initialLocalTime = widget.initialDate.toLocal();
    // 若调用方只给了日期（时间为 00:00:00.000），默认把 time 部分设为当前本地时间，
    // 避免 header 中显示「00:00」，而是显示「现在时间」。
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
    _displayedMonth = DateTime(
      _selected.year,
      _selected.month,
    );
    _activeHour = _selected.hour;
    _activeMinute = _selected.minute;
    _hourController = FixedExtentScrollController(
      initialItem: _activeHour,
    );
    _minuteController = FixedExtentScrollController(
      initialItem: _activeMinute,
    );
    _yearScrollController = ScrollController();
    _yearKeys = <int, GlobalKey>{
      for (int y = widget.firstDate.year; y <= widget.lastDate.year; y++)
        y: GlobalKey(),
    };
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _yearScrollController.dispose();
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

  void _selectYear(int year) {
    final DateTime candidate = DateTime(year, _displayedMonth.month);
    if (_isMonthAllowed(candidate)) {
      setState(() {
        _displayedMonth = candidate;
        _isYearPickerOpen = false;
      });
    }
  }

  void _toggleYearPicker() {
    setState(() => _isYearPickerOpen = !_isYearPickerOpen);
    if (_isYearPickerOpen) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToSelectedYear(),
      );
    }
  }

  void _scrollToSelectedYear() {
    final GlobalKey? key = _yearKeys[_displayedMonth.year];
    final BuildContext? ctx = key?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: const Duration(milliseconds: 250),
    );
  }

  void _selectDay(int day) {
    setState(() {
      _selected = DateTime(
        _displayedMonth.year,
        _displayedMonth.month,
        day,
        _selected.hour,
        _selected.minute,
      );
    });
  }

  /// 获取当前本地时间。
  ///
  /// 某些运行环境（如 iOS 模拟器）下 `DateTime.now()` 会返回 UTC，
  /// 此时按 GMT+8 兜底，确保中国用户看到正确的「现在时间」。
  DateTime _localNow() {
    final DateTime now = DateTime.now();
    if (now.timeZoneOffset == Duration.zero) {
      return now.add(const Duration(hours: 8));
    }
    return now.toLocal();
  }

  void _jumpToCurrent() {
    final DateTime now = _localNow();
    if (_isTimeView) {
      _hourController.jumpToItem(now.hour);
      _minuteController.jumpToItem(now.minute);
      _activeHour = now.hour;
      _activeMinute = now.minute;
    }
    setState(() {
      _selected = now;
      _displayedMonth = DateTime(now.year, now.month);
      _isYearPickerOpen = false;
      _isTimeView = false;
    });
  }

  // ---- 视图切换 ----

  void _onConfirm() {
    Navigator.of(context).pop(_selected);
  }

  // ---- 日期矩阵 ----

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
    // Flutter weekday: Monday=1 ... Sunday=7。以周日为首列。
    final int leading = firstDay.weekday % 7;
    final List<int?> days = <int?>[
      for (int i = 0; i < leading; i++) null,
      for (int i = 1; i <= daysInMonth; i++) i,
    ];
    while (days.length % 7 != 0) {
      days.add(null);
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final double sheetHeight =
        (MediaQuery.of(context).size.height * 0.45).clamp(340.0, 420.0);

    return SafeArea(
      child: SizedBox(
        height: sheetHeight,
        child: Column(
          children: <Widget>[
            _buildHeader(),
            const SizedBox(height: AppDimens.spaceMd),
            if (_isYearPickerOpen)
              _buildYearPicker()
            else if (_isTimeView)
              _buildTimeView()
            else
              _buildCalendarBody(),
          ],
        ),
      ),
    );
  }

  // ---- Header（关闭 / 当前时间 / 信息 / 确认）----

  Widget _buildHeader() {
    final String infoText = _isTimeView
        ? DateFormat('M-d').format(_selected)
        : DateFormat('HH:mm').format(_selected);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceLg,
        AppDimens.spaceMd,
        AppDimens.spaceLg,
        0,
      ),
      child: Row(
        children: <Widget>[
          _CircleIconButton(
            icon: Icons.close,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          _ChipButton(
            label: widget.currentTimeLabel,
            onPressed: _jumpToCurrent,
          ),
          const SizedBox(width: AppDimens.spaceSm),
          _ChipButton(
            label: infoText,
            muted: true,
            onPressed: widget.showTime
                ? () => setState(() {
                      _isTimeView = !_isTimeView;
                      _isYearPickerOpen = false;
                    })
                : null,
          ),
          const SizedBox(width: AppDimens.spaceSm),
          _ConfirmButton(onPressed: _onConfirm),
        ],
      ),
    );
  }

  // ---- 日历主体 ----

  Widget _buildCalendarBody() {
    final bool canGoPrevious = _isMonthAllowed(
      DateTime(_displayedMonth.year, _displayedMonth.month - 1),
    );
    final bool canGoNext = _isMonthAllowed(
      DateTime(_displayedMonth.year, _displayedMonth.month + 1),
    );

    return Expanded(
      child: Column(
        children: <Widget>[
          // 年月导航
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceLg,
            ),
            child: Row(
              children: <Widget>[
                InkWell(
                  onTap: _toggleYearPicker,
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spaceSm,
                      vertical: AppDimens.spaceXs,
                    ),
                    child: Row(
                      children: <Widget>[
                        Text(
                          _isYearPickerOpen
                              ? '${_displayedMonth.year}年'
                              : DateFormat('yyyy年M月').format(_displayedMonth),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: AppDimens.spaceXs),
                        Icon(
                          _isYearPickerOpen
                              ? Icons.expand_less
                              : Icons.expand_more,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                _IconArrow(
                  icon: Icons.chevron_left,
                  enabled: canGoPrevious,
                  onPressed: _previousMonth,
                ),
                _IconArrow(
                  icon: Icons.chevron_right,
                  enabled: canGoNext,
                  onPressed: _nextMonth,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          const _WeekdayRow(),
          const SizedBox(height: AppDimens.spaceSm),
          _buildDayGrid(),
        ],
      ),
    );
  }

  Widget _buildDayGrid() {
    final List<int?> days = _buildDaysMatrix();
    final DateTime selectedDayOnly = DateTime(
      _selected.year,
      _selected.month,
      _selected.day,
    );
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg),
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
            final bool isAfterSelected = date.isAfter(selectedDayOnly);
            final bool isAllowed = _isDayAllowed(date);
            final bool isMuted = !isSelected && (isAfterSelected || !isAllowed);
            return _DayCell(
              day: day,
              isSelected: isSelected,
              isMuted: isMuted,
              isEnabled: isAllowed,
              onTap: () => _selectDay(day),
            );
          }).toList(growable: false),
        ),
      ),
    );
  }

  // ---- 年份选择器 ----

  Widget _buildYearPicker() {
    final int start = widget.firstDate.year;
    final int end = widget.lastDate.year;
    final List<int> years = <int>[
      for (int y = start; y <= end; y++) y,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(
            left: AppDimens.spaceLg,
            top: AppDimens.spaceMd,
            bottom: AppDimens.spaceSm,
          ),
          child: InkWell(
            onTap: () => setState(() => _isYearPickerOpen = false),
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceSm,
                vertical: AppDimens.spaceXs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '${_displayedMonth.year}年${_displayedMonth.month}月',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                  ),
                  const SizedBox(width: AppDimens.spaceXs),
                  const Icon(
                    Icons.expand_less,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(
          height: 240,
          child: GridView.count(
            controller: _yearScrollController,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceLg,
            ),
            crossAxisCount: 4,
            mainAxisSpacing: AppDimens.spaceSm,
            crossAxisSpacing: AppDimens.spaceSm,
            childAspectRatio: 2.2,
            children: years.map((int year) {
              final bool isSelected = year == _displayedMonth.year;
              return GestureDetector(
                onTap: () => _selectYear(year),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  key: _yearKeys[year],
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  ),
                  child: Text(
                    '$year',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color:
                              isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                  ),
                ),
              );
            }).toList(growable: false),
          ),
        ),
      ],
    );
  }

  // ---- 时间滚轮 ----

  Widget _buildTimeView() {
    return Expanded(
      child: Column(
        children: <Widget>[
          Expanded(
            child: _TimeWheel(
              hourController: _hourController,
              minuteController: _minuteController,
              activeHour: _activeHour,
              activeMinute: _activeMinute,
              onHourChanged: (int v) => setState(() {
                _activeHour = v;
                _selected = DateTime(
                  _selected.year,
                  _selected.month,
                  _selected.day,
                  v,
                  _selected.minute,
                );
              }),
              onMinuteChanged: (int v) => setState(() {
                _activeMinute = v;
                _selected = DateTime(
                  _selected.year,
                  _selected.month,
                  _selected.day,
                  _selected.hour,
                  v,
                );
              }),
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
        ],
      ),
    );
  }
}

/// 时间滚轮：小时 / 分钟 双列，中心高亮条。
class _TimeWheel extends StatelessWidget {
  const _TimeWheel({
    required this.hourController,
    required this.minuteController,
    required this.activeHour,
    required this.activeMinute,
    required this.onHourChanged,
    required this.onMinuteChanged,
  });

  final FixedExtentScrollController hourController;
  final FixedExtentScrollController minuteController;
  final int activeHour;
  final int activeMinute;
  final ValueChanged<int> onHourChanged;
  final ValueChanged<int> onMinuteChanged;

  static const double _itemExtent = 44;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        // 中心高亮条
        Positioned.fill(
          child: Center(
            child: Container(
              height: _itemExtent,
              margin: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceSm,
              ),
              decoration: BoxDecoration(
                color: _wheelHighlight,
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              ),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SizedBox(
              width: 56,
              child: _buildColumn(
                context,
                count: 24,
                controller: hourController,
                active: activeHour,
                onChanged: onHourChanged,
              ),
            ),
            const SizedBox(width: AppDimens.spaceSm),
            const _Label('小时'),
            const SizedBox(width: AppDimens.spaceMd),
            SizedBox(
              width: 56,
              child: _buildColumn(
                context,
                count: 60,
                controller: minuteController,
                active: activeMinute,
                onChanged: onMinuteChanged,
              ),
            ),
            const SizedBox(width: AppDimens.spaceSm),
            const _Label('分钟'),
          ],
        ),
      ],
    );
  }

  Widget _buildColumn(
    BuildContext context, {
    required int count,
    required FixedExtentScrollController controller,
    required int active,
    required ValueChanged<int> onChanged,
  }) {
    return ListWheelScrollView(
      controller: controller,
      itemExtent: _itemExtent,
      diameterRatio: 1.6,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: onChanged,
      children: <Widget>[
        for (int i = 0; i < count; i++)
          Center(
            child: Text(
              i.toString().padLeft(2, '0'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: i == active
                        ? AppColors.textPrimary
                        : AppColors.textTertiary,
                    fontWeight:
                        i == active ? FontWeight.w700 : FontWeight.normal,
                  ),
            ),
          ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
      );
}

// ---- 小组件 ----

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(
          color: AppColors.surfaceLight,
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: Icon(icon, size: 18, color: AppColors.textSecondary),
          padding: EdgeInsets.zero,
          onPressed: onPressed,
        ),
      );
}

class _ChipButton extends StatelessWidget {
  const _ChipButton({
    required this.label,
    this.onPressed,
    this.muted = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool muted;

  @override
  Widget build(BuildContext context) => Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
        decoration: BoxDecoration(
          color: muted ? Colors.transparent : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            minimumSize: Size.zero,
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: muted ? AppColors.textSecondary : AppColors.textPrimary,
            ),
          ),
        ),
      );
}

class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            minimumSize: Size.zero,
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            '确认',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      );
}

class _IconArrow extends StatelessWidget {
  const _IconArrow({
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        icon: Icon(icon, color: AppColors.textSecondary),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        onPressed: enabled ? onPressed : null,
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

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg),
        child: Row(
          children: _labels
              .map(
                (String label) => Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
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
    required this.isMuted,
    required this.isEnabled,
    required this.onTap,
  });

  final int day;
  final bool isSelected;
  final bool isMuted;
  final bool isEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$day',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isSelected
                  ? Colors.white
                  : (isMuted ? AppColors.textTertiary : AppColors.textPrimary),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
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
