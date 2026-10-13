import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';

/// 底部粘性操作栏（全应用统一）：奶油底 + 顶部发丝线，承载保存/取消按钮。
///
/// 默认取主题 [ColorScheme.surface] / [ColorScheme.outline]，与储蓄/分期页
/// 已对齐的「surfaceLight + hairline 顶边」一致。
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    super.key,
    required this.child,
    this.backgroundColor,
    this.borderColor,
    this.padding = const EdgeInsets.fromLTRB(
      AppDimens.lg,
      AppDimens.md,
      AppDimens.lg,
      AppDimens.md,
    ),
    this.useSafeArea = true,
  });

  final Widget child;
  final Color? backgroundColor;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;
  final bool useSafeArea;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Widget bar = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? scheme.surface,
        border: Border(
          top: BorderSide(color: borderColor ?? scheme.outline, width: 1),
        ),
      ),
      child: child,
    );
    return useSafeArea ? SafeArea(top: false, child: bar) : bar;
  }
}
