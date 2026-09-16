import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimens.dart';

/// 小青账风格的底部日期选择面板。
///
/// 用法：
/// ```dart
/// final DateTime? picked = await DatePickerSheet.show(
///   context,
///   initialDate: DateTime.now(),
/// );
/// ```
class DatePickerSheet {
  DatePickerSheet._();

  /// 弹出底部日期选择器。
  ///
  /// 交互约定：
  /// - 点击日期直接返回并关闭面板。
  /// - 点击左上角关闭按钮返回 `null`。
  /// - 点击「当前时间」快速定位到今天。
  /// - 点击年月文本展开年份选择，选择年份后自动折叠。
  static Future<DateTime?> show(
    BuildContext context, {
    required DateTime initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
    String currentTimeLabel = '当前时间',
  }) async {
    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusLg),
        ),
      ),
      builder: (BuildContext ctx) => _DatePickerSheetBody(
        initialDate: initialDate,
        firstDate: firstDate ?? DateTime(2000),
        lastDate: lastDate ?? DateTime(2100),
        currentTimeLabel: currentTimeLabel,
      ),
    );
  }
}

class _DatePickerSheetBody extends StatefulWidget {
  const _DatePickerSheetBody({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.currentTimeLabel,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String currentTimeLabel;

  @override
  State<_DatePickerSheetBody> createState() => _DatePickerSheetBodyState();
}

class _DatePickerSheetBodyState extends State<_DatePickerSheetBody> {
  late DateTime _selected;
  late DateTime _displayedMonth;
  bool _isYearPickerOpen = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDate;
    _displayedMonth = DateTime(widget.initialDate.year, widget.initialDate.month);
  }

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

  bool _isMonthAllowed(DateTime month) {
    final DateTime first = DateTime(widget.firstDate.year, widget.firstDate.month);
    final DateTime last = DateTime(widget.lastDate.year, widget.lastDate.month);
    return !month.isBefore(first) && !month.isAfter(last);
  }

  bool _isDayAllowed(DateTime day) {
    return !day.isBefore(widget.firstDate) && !day.isAfter(widget.lastDate);
  }

  void _selectDay(int day) {
    final DateTime candidate = DateTime(
      _displayedMonth.year,
      _displayedMonth.month,
      day,
    );
    if (_isDayAllowed(candidate)) {
      Navigator.of(context).pop(candidate);
    }
  }

  void _jumpToCurrent() {
    final DateTime now = DateTime.now();
    setState(() {
      _displayedMonth = DateTime(now.year, now.month);
      _selected = now;
    });
  }

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
    // Flutter weekday: Monday=1 ... Sunday=7. We want Sunday as the first column.
    final int leading = firstDay.weekday % 7;
    final List<int?> days = <int?>[
      for (int i = 0; i < leading; i++) null,
      for (int i = 1; i <= daysInMonth; i++) i,
    ];
    // Pad to a multiple of 7 so the grid stays rectangular.
    while (days.length % 7 != 0) {
      days.add(null);
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool canGoPrevious = _isMonthAllowed(
      DateTime(_displayedMonth.year, _displayedMonth.month - 1),
    );
    final bool canGoNext = _isMonthAllowed(
      DateTime(_displayedMonth.year, _displayedMonth.month + 1),
    );

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Header: close + current time
            Row(
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _jumpToCurrent,
                  child: Text(widget.currentTimeLabel),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceMd),
            // Month navigator: left-aligned year-month with expand arrow,
            // month prev/next on the right.
            Row(
              children: <Widget>[
                InkWell(
                  onTap: () => setState(
                    () => _isYearPickerOpen = !_isYearPickerOpen,
                  ),
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spaceSm,
                      vertical: AppDimens.spaceXs,
                    ),
                    child: Row(
                      children: <Widget>[
                        Text(
                          DateFormat('yyyy年M月').format(_displayedMonth),
                          style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
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
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed:
                      canGoPrevious && !_isYearPickerOpen ? _previousMonth : null,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed:
                      canGoNext && !_isYearPickerOpen ? _nextMonth : null,
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceMd),
            // Body: year picker or weekday + day grid
            if (_isYearPickerOpen)
              _buildYearPicker()
            else ...<Widget>[
              const _WeekdayRow(),
              const SizedBox(height: AppDimens.spaceSm),
              _buildDayGrid(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildYearPicker() {
    final int start = widget.firstDate.year;
    final int end = widget.lastDate.year;
    final List<int> years = <int>[
      for (int y = start; y <= end; y++) y,
    ];
    return SizedBox(
      height: 280,
      child: GridView.builder(
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 1.5,
        ),
        itemCount: years.length,
        itemBuilder: (BuildContext context, int index) {
          final int year = years[index];
          final bool isSelected = year == _displayedMonth.year;
          return Center(
            child: InkWell(
              onTap: () => _selectYear(year),
              customBorder: const CircleBorder(),
              child: Container(
                width: 64,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
                child: Text(
                  '$year',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDayGrid() {
    final List<int?> days = _buildDaysMatrix();
    return GridView.count(
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
        final bool isSelected = _selected.year == date.year &&
            _selected.month == date.month &&
            _selected.day == date.day;
        final bool isAllowed = _isDayAllowed(date);
        return _DayCell(
          day: day,
          isSelected: isSelected,
          isEnabled: isAllowed,
          onTap: () => _selectDay(day),
        );
      }).toList(growable: false),
    );
  }
}

class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow();

  static const List<String> _labels = <String>['日', '一', '二', '三', '四', '五', '六'];

  @override
  Widget build(BuildContext context) {
    return Row(
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
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isSelected,
    required this.isEnabled,
    required this.onTap,
  });

  final int day;
  final bool isSelected;
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
                      : (isEnabled ? AppColors.textPrimary : AppColors.textTertiary),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
          ),
        ),
      ),
    );
  }
}
