import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 轻量日期选择行（可选清除）。多个模块表单复用。
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.allowClear = false,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool allowClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(label),
            subtitle: Text(
              value == null
                  ? '未设置'
                  : DateFormat('yyyy-MM-dd').format(value!),
            ),
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: value ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
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
