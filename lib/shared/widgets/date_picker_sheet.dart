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
  static Future<DateTime?> show(
    BuildContext context, {
    required DateTime initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
    String title = '选择日期',
    String currentTimeLabel = '当前时间',
    String cancelLabel = '取消',
    String confirmLabel = '确定',
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
        title: title,
        currentTimeLabel: currentTimeLabel,
        cancelLabel: cancelLabel,
        confirmLabel: confirmLabel,
      ),
    );
  }
}

class _DatePickerSheetBody extends StatefulWidget {
  const _DatePickerSheetBody({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.title,
    required this.currentTimeLabel,
    required this.cancelLabel,
    required this.confirmLabel,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String title;
  final String currentTimeLabel;
  final String cancelLabel;
  final String confirmLabel;

  @override
  State<_DatePickerSheetBody> createState() => _DatePickerSheetBodyState();
}

class _DatePickerSheetBodyState extends State<_DatePickerSheetBody> {
  late DateTime _selected;
  late DateTime _displayedMonth;

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

  bool _isMonthAllowed(DateTime month) {
    final DateTime first = DateTime(widget.firstDate.year, widget.firstDate.month);
    final DateTime last = DateTime(widget.lastDate.year, widget.lastDate.month);
    return !month.isBefore(first) && !month.isAfter(last);
  }

  bool _isDayAllowed(DateTime day) {
    return !day.isBefore(widget.firstDate) && !day.isAfter(widget.lastDate);
  }

  void _selectDay(int day) {
    final DateTime candidate = DateTime(_displayedMonth.year, _displayedMonth.month, day);
    if (_isDayAllowed(candidate)) {
      setState(() => _selected = candidate);
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
    final List<int?> days = _buildDaysMatrix();
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
            // Header
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
            // Month navigator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: canGoPrevious ? _previousMonth : null,
                ),
                Text(
                  DateFormat('yyyy年M月').format(_displayedMonth),
                  style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: canGoNext ? _nextMonth : null,
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceMd),
            // Weekday labels
            const _WeekdayRow(),
            const SizedBox(height: AppDimens.spaceSm),
            // Day grid
            GridView.count(
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
            ),
            const SizedBox(height: AppDimens.spaceLg),
            // Actions
            Row(
              children: <Widget>[
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(widget.cancelLabel),
                  ),
                ),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(_selected),
                    child: Text(widget.confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
