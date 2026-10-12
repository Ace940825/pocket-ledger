import 'package:flutter/material.dart';

/// 着色图标方块 / 圆（全应用统一）。
///
/// 收敛各页手搭的 `_CircleIcon`：半透明着色底 + 居中 [child]。
/// - 账户 / 账单列表里的分类图标圆角方块（默认 44×44、圆角 12）；
/// - 选择页里的圆形图标（[circle]=true）。
/// 暗色下自动加深着色透明度，文字色走主题。
class TintedIconBox extends StatelessWidget {
  const TintedIconBox({
    super.key,
    required this.child,
    required this.tint,
    this.size = 44,
    this.radius = 12,
    this.circle = false,
  });

  final Widget child;
  final Color tint;
  final double size;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: isDark ? 0.18 : 0.12),
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}
