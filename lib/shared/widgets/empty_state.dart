import 'package:flutter/material.dart';

import '../../core/constants/app_dimens.dart';

/// 空状态占位。
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.message,
    super.key,
    this.icon = Icons.inbox_outlined,
    this.iconWidget,
    this.subMessage,
    this.action,
    this.padding,
    this.gap,
    this.subGap,
    this.textStyle,
  });

  final String message;
  final IconData icon;

  /// 自定义图标区（如品牌化圆形象征）。提供时覆盖默认 Material [icon]。
  final Widget? iconWidget;

  /// 次要说明行（显示在 [message] 下方，字号自动收紧一档）。
  final String? subMessage;
  final Widget? action;

  /// 整体内边距，默认 [AppDimens.spaceXl] 四周。
  final EdgeInsetsGeometry? padding;

  /// 图标与文案之间的间距，默认 [AppDimens.spaceLg]。
  final double? gap;

  /// 主文案与 [subMessage] 之间的间距，默认 4。
  final double? subGap;

  /// 文案样式（[subMessage] 会在此基础上字号收紧至 11）。
  /// 默认 [TextTheme.bodyMedium] + [ColorScheme.onSurfaceVariant]。
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final EdgeInsetsGeometry resolvedPadding =
        padding ?? const EdgeInsets.all(AppDimens.spaceXl);
    final double resolvedGap = gap ?? AppDimens.spaceLg;
    final double resolvedSubGap = subGap ?? 4;
    final TextStyle? resolvedTextStyle = textStyle ??
        theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        );
    final Widget iconSlot = iconWidget ??
        Icon(
          icon,
          size: 56,
          color: theme.colorScheme.outlineVariant,
        );
    return Center(
      child: Padding(
        padding: resolvedPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            iconSlot,
            SizedBox(height: resolvedGap),
            Text(
              message,
              textAlign: TextAlign.center,
              style: resolvedTextStyle,
            ),
            if (subMessage != null) ...<Widget>[
              SizedBox(height: resolvedSubGap),
              Text(
                subMessage!,
                textAlign: TextAlign.center,
                style: resolvedTextStyle?.copyWith(fontSize: 11),
              ),
            ],
            if (action != null) ...<Widget>[
              SizedBox(height: resolvedGap),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
