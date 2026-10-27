import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';

/// 奶油卡 + 发丝线描边（全应用统一卡片底盘）。
///
/// 默认取主题 [ColorScheme.surface] / [ColorScheme.outline] —— 亮色下即
/// [context.forest.surface] / [AppPalette.hairline]，与既有储蓄/投资页完全一致；
/// 暗色下自动转暗底，无需硬编码。
///
/// 迁移既有 `Container(BoxDecoration(color: context.forest.surface, border:
/// Border.all(color: AppPalette.hairline)))` 时可直接替换，零视觉漂移；
/// Forest 系页面（context.forest.surface / AppPalette.hairline）请在迁移时显式传入
/// 原色，待「双奶油/双发丝线」统一决策后再去参。
class HairlineCard extends StatelessWidget {
  const HairlineCard({
    super.key,
    required this.child,
    this.backgroundColor,
    this.borderColor,
    this.radius = AppDimens.radiusCard,
    this.borderWidth = 1,
    this.padding = const EdgeInsets.all(AppDimens.md),
    this.margin,
    this.shadows,
  });

  final Widget child;
  final Color? backgroundColor;
  final Color? borderColor;
  final double radius;
  final double borderWidth;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final List<BoxShadow>? shadows;

  @override
  Widget build(BuildContext context) {

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? context.forest.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? context.forest.outline,
          width: borderWidth,
        ),
        boxShadow: shadows,
      ),
      child: child,
    );
  }
}
