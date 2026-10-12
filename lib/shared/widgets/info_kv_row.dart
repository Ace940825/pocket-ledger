import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';

/// 信息键值行（全应用统一）：左标签 + 右值，可选点击。
///
/// 用于详情页 / 设置页的「标签 : 值」单行。文字色走主题，暗色自动适配。
/// 值区域占满剩余宽度并右对齐；值过长时自动换行（不再溢出/截断），
/// 换行对齐方式由值自身（[Text.textAlign]）决定。
class InfoKVRow extends StatelessWidget {
  const InfoKVRow({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
    this.labelStyle,
    this.valueStyle,
    this.padding = const EdgeInsets.symmetric(vertical: 6),
  });

  final String label;
  final Widget value;
  final VoidCallback? onTap;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Widget labelText = Text(
      label,
      style:
          labelStyle ?? TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
    );
    final Widget valueText = DefaultTextStyle(
      style: valueStyle ??
          TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: scheme.onSurface,
          ),
      child: value,
    );
    final Widget row = Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          labelText,
          const SizedBox(width: 12),
          // 值占满剩余宽度、右对齐；长值（如退款备注）自动换行而非溢出。
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: valueText,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}
