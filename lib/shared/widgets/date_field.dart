import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import 'date_picker_sheet.dart';
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
              color: AppColors.textSecondary,
            ),
            title: Text(label),
            subtitle: Text(
              value == null ? '未设置' : DateFormat(formatPattern).format(value!),
            ),
            onTap: () async {
              final DateTime? picked = await DateTimePickerSheet.show(
                context,
                initialDate: value ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                showTime: showTime,
              );
              if (picked != null) onChanged(picked);
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
