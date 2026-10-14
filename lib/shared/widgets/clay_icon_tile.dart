import 'package:flutter/material.dart';

/// 黏土方糖图标容器（全应用统一，A3 视觉）：白→分类彩双色渐变软糖底 +
/// 左上高光斑 + 长投影。选中态转实体分类色、去高光。
///
/// 由记一笔主网格的 `_ClayIconTile` 提升而来（2026-10-14 真机反馈：
/// 图标风格全局统一为黏土方糖）。分类/账户/借还等行内图标统一用本组件，
/// 线稿配色走约定：`Color.lerp(color, scheme.onSurface, 0.22)`。
class ClayIconTile extends StatelessWidget {
  const ClayIconTile({
    super.key,
    required this.color,
    required this.child,
    this.selected = false,
    this.size = 42,
    this.radius,
  });

  /// 分类色（渐变深端 / 选中态实底）。
  final Color color;

  /// 选中态：实底分类色、去高光（记一笔主网格选中用）。
  final bool selected;

  final Widget child;

  /// 边长（默认 42，与记一笔主网格一致）。
  final double size;

  /// 圆角（默认随尺寸等比缩放：42 → 13）。
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final double effRadius = radius ?? size * 13 / 42;
    // 加深黏土底：分类色混入比例 0.32 → 0.5（用户反馈图标整体偏淡）
    final Color tint =
        Color.lerp(Colors.white, color, 0.5)!; // ignore: no_raw_colors
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? color : null,
        gradient: selected
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Colors.white, tint], // ignore: no_raw_colors
                stops: const <double>[0, 0.78],
              ),
        borderRadius: BorderRadius.circular(effRadius),
        border: Border.all(
          color: selected
              ? Colors.transparent
              : Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
        ),
        boxShadow: <BoxShadow>[
          // 未选中：设计稿 5px 7px 14px rgba(74,66,46,.20)（微收敛防格间溢出）
          // 选中：0 6px 14px rgba(74,66,46,.22)
          BoxShadow(
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
            offset: selected ? const Offset(0, 6) : const Offset(3, 4),
            blurRadius: selected ? 14 : 10,
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          if (!selected)
            // 左上高光斑：铺满整块的 radial-gradient
            // （circle at 40% 35%, rgba(255,255,255,.92), transparent 70%）。
            // 注意结束色必须用「透明白」而非 Colors.transparent——后者是
            // 透明黑，RGBA 直插值中途会变成半透明灰，在浅底上显示为灰斑。
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(effRadius),
                  gradient: RadialGradient(
                    center: const Alignment(-0.2, -0.3),
                    radius: 0.9,
                    colors: <Color>[
                      Theme.of(context)
                          .colorScheme
                          .surface
                          .withValues(alpha: 0.92),
                      Theme.of(context)
                          .colorScheme
                          .surface
                          .withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          Center(child: child),
        ],
      ),
    );
  }
}
