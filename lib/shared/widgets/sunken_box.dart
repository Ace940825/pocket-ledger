import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// 凹陷描边盒（下沉底色 + 发丝线描边），全应用「凹陷字段 / 占位」统一底盘。
///
/// 与 [HairlineCard]（凸起奶油卡）互为表里：本组件表达「内凹」视觉，用于
/// 输入框外壳、图标占位、拖拽空槽、标签行等需要下沉感的元素。
/// fill = `context.colors.surfaceContainerHighest`（亮 = paper2 #F4EEDE，
/// 暗 = #33332A，随主题自适应），与全应用输入框/选择框底色统一；
/// border = [AppPalette.hairline]（= ColorScheme.outline）。
class SunkenBox extends StatelessWidget {
  const SunkenBox({
    super.key,
    this.child,
    this.width,
    this.height,
    this.constraints,
    this.padding,
    this.margin,
    this.alignment,
    this.radius = 12,
    this.borderWidth = 1,
    this.shape = BoxShape.rectangle,
    this.borderColor,
  });

  final Widget? child;
  final double? width;
  final double? height;
  final BoxConstraints? constraints;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final AlignmentGeometry? alignment;
  final double radius;
  final double borderWidth;
  final BoxShape shape;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        constraints: constraints,
        padding: padding,
        margin: margin,
        alignment: alignment,
        decoration: BoxDecoration(
          color: context.colors.surfaceContainerHighest,
          shape: shape,
          borderRadius:
              shape == BoxShape.circle ? null : BorderRadius.circular(radius),
          border: Border.all(
            color: borderColor ?? Theme.of(context).colorScheme.outline,
            width: borderWidth,
          ),
        ),
        child: child,
      );
}
