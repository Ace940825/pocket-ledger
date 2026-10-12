import 'package:flutter/material.dart';

/// 小徽标 / 标签胶囊（全应用统一）。
///
/// 取代各页手搭的 `_Badge`：圆角小胶囊，[color] 为底色、文字默认取
/// `colorScheme.onPrimary`（白字）；用于设置行上的「归组 / 合并 / 已移除」等状态标。
///
/// 可选 [textColor] 覆盖文字色（如浅绿底配深绿字）、[radius] 改圆角（999 = 全圆药丸）、
/// [scale] 随父级自适应缩放。
class BadgePill extends StatelessWidget {
  const BadgePill({
    super.key,
    required this.text,
    required this.color,
    this.textColor,
    this.radius = 5,
    this.scale = 1.0,
  });

  final String text;
  final Color color;
  final Color? textColor;
  final double radius;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 5 * scale,
        vertical: 2 * scale,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius * scale),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10 * scale,
          fontWeight: FontWeight.w700,
          color: textColor ?? Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }
}
