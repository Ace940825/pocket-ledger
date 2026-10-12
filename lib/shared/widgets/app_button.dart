import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';

/// 统一按钮（全应用一致圆角 [AppDimens.radiusKey] + 触控高度 + padding）。
///
/// 收敛各页 `FilledButton.styleFrom` / `OutlinedButton.styleFrom` 的重复样板。
/// 三种变体分别保留 Material 3 的配色语义：
/// - [PrimaryButton]：实心（primary 填充）
/// - [TonalButton]：tonal（surfaceVariant 浅填）
/// - [OutlinedAppButton]：描边（透明底 + outline）
///
/// 样式（形状 / 最小高度 / 内边距）共用 [_buttonStyle]，颜色交给各按钮类型默认。

/// 共用按钮样式：仅约束形状 / 尺寸 / padding，颜色留给具体按钮类型。
ButtonStyle _buttonStyle() => ButtonStyle(
      minimumSize: WidgetStateProperty.all(
        const Size.fromHeight(AppDimens.minTouch),
      ),
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(
          horizontal: AppDimens.lg,
          vertical: 10,
        ),
      ),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusKey),
        ),
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

/// 按钮内文：图标（可选）+ 文案，整体居中。
Widget _buttonChild(String label, Widget? icon) => Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (icon != null) ...<Widget>[icon, const SizedBox(width: 8)],
        Text(label),
      ],
    );

/// 全宽 / 自适应包裹：fullWidth 时占满父宽。
Widget _wrap(Widget button, bool fullWidth) =>
    fullWidth ? SizedBox(width: double.infinity, child: button) : button;

/// 主操作按钮（实心）。
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) => _wrap(
        FilledButton(
          onPressed: onPressed,
          style: _buttonStyle(),
          child: _buttonChild(label, icon),
        ),
        fullWidth,
      );
}

/// 次操作按钮（tonal 浅填）。
class TonalButton extends StatelessWidget {
  const TonalButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) => _wrap(
        FilledButton.tonal(
          onPressed: onPressed,
          style: _buttonStyle(),
          child: _buttonChild(label, icon),
        ),
        fullWidth,
      );
}

/// 描边按钮（透明底 + 发丝线）。
class OutlinedAppButton extends StatelessWidget {
  const OutlinedAppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) => _wrap(
        OutlinedButton(
          onPressed: onPressed,
          style: _buttonStyle(),
          child: _buttonChild(label, icon),
        ),
        fullWidth,
      );
}
