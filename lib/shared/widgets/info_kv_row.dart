import 'package:flutter/material.dart';
import 'package:pocket_ledger/core/theme/forest_design_tokens.dart';

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

    // 自定义样式未显式给色时必须并入主题色：裸 TextStyle(fontWeight:…) 经
    // DefaultTextStyle 下传后取不到 Material 默认墨色，值会渲染成几乎不可见
    // 的浅灰（成交回执「数量/单价/手续费」不可见，2026-10-16 第 43 批）。
    final TextStyle effectiveLabelStyle =
        (labelStyle ?? const TextStyle(fontSize: 14))
            .copyWith(color: labelStyle?.color ?? context.forest.onSurfaceVariant);
    final TextStyle effectiveValueStyle = (valueStyle ??
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))
        .copyWith(color: valueStyle?.color ?? context.forest.onSurface);
    final Widget labelText = Text(label, style: effectiveLabelStyle);
    final Widget valueText = DefaultTextStyle(
      style: effectiveValueStyle,
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
