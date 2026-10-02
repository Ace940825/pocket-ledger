import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/app_colors.dart';
import 'calendar_sheet.dart';
import 'line_icons.dart';

/// 轻量日期选择行（可选清除）。多个模块表单复用。
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.allowClear = false,
    this.showTime = false,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool allowClear;
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    final String formatPattern = showTime ? 'yyyy-MM-dd HH:mm' : 'yyyy-MM-dd';
    return Row(
      children: <Widget>[
        Expanded(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: LineIcon(
              LineIconKind.calendar,
              size: 20,
              color: AppPalette.textSecondary,
            ),
            title: Text(label),
            subtitle: Text(
              value == null ? '未设置' : DateFormat(formatPattern).format(value!),
            ),
            onTap: () async {
              final DateTime base = value ?? DateTime.now();
              final CalendarSelection? picked = await CalendarSheet.show(
                context,
                mode: CalendarSheetMode.day,
                initialDate: base,
                firstDate: DateTime(2000),
                lastDate: DateTime(2107, 12, 31),
                showTime: showTime,
                showQuickChips: true,
                weekStart: CalendarWeekStart.sunday,
              );
              if (picked == null) return;
              // day 模式返回单日（含所选时分）；若选了周期则取起点日并保留原时分。
              final DateTime resolved;
              if (picked is CalendarDay) {
                resolved = picked.date;
              } else if (picked is CalendarPeriod) {
                final DateTime s = picked.start;
                resolved = DateTime(s.year, s.month, s.day, base.hour, base.minute);
              } else {
                return;
              }
              onChanged(resolved);
            },
          ),
        ),
        if (allowClear && value != null)
          IconButton(
            icon: const Icon(Icons.clear, size: 18),
            onPressed: () => onChanged(null),
          ),
      ],
    );
  }
}
