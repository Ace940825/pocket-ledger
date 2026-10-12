import 'package:flutter/material.dart';

/// 头像/图标块（全应用统一）：圆形或圆角方块容器，承载账户/分类/账单图标。
///
/// 仅负责「容器 + 尺寸」，图标内容由调用方传入，避免与数据层耦合。
class AvatarTile extends StatelessWidget {
  const AvatarTile({
    super.key,
    required this.child,
    this.size = 34,
    this.backgroundColor,
    this.radius,
    this.padding,
    this.border,
  });

  final Widget child;
  final double size;
  final Color? backgroundColor;
  final double? radius;
  final EdgeInsetsGeometry? padding;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius ?? size / 2),
        border: border,
      ),
      child: Center(child: child),
    );
  }
}
