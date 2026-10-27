import 'package:flutter/material.dart';
import 'package:pocket_ledger/core/theme/forest_design_tokens.dart';

import '../../theme/app_dimens.dart';
import '../../theme/app_theme.dart';

/// 统一确认弹窗（全应用）。
///
/// 取代各页手搭的 `AlertDialog`：固定圆角、语义化按钮、危险操作红字、
/// 点遮罩 / 取消均可关闭（分别返回 null / false），读屏语义由 AlertDialog 自带。
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    this.title,
    required this.content,
    this.confirmText = '确定',
    this.cancelText = '取消',
    this.danger = false,
    this.onConfirm,
    this.onCancel,
  });

  final String? title;
  final String content;
  final String confirmText;

  /// 取消按钮文案；传 `null` 时不渲染取消按钮（单按钮说明型弹窗，
  /// 如「关于 XX」帮助说明）。默认「取消」。
  final String? cancelText;
  final bool danger;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {

    final Color confirmColor = danger ? context.forest.error : context.forest.primary;
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      title: title == null
          ? null
          : Text(
              title!,
              style: context.text.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
      content: Text(
        content,
        style: context.text.bodyMedium?.copyWith(
          color: context.forest.onSurfaceVariant,
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppDimens.md,
        0,
        AppDimens.md,
        AppDimens.md,
      ),
      actions: <Widget>[
        if (cancelText != null)
          TextButton(
            onPressed: () {
              onCancel?.call();
              Navigator.of(context).pop(false);
            },
            child: Text(cancelText!),
          ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: confirmColor),
          onPressed: () {
            onConfirm?.call();
            Navigator.of(context).pop(true);
          },
          child: Text(confirmText),
        ),
      ],
    );
  }
}

/// 便捷方法：弹出确认弹窗。
///
/// 返回 `true`=确认 / `false`=取消按钮 / `null`=点遮罩关闭。
/// 调用方统一用 `if (confirmed != true) return;` 处理非确认分支即可。
/// [cancelText] 传 `null` 时不显示取消按钮（单按钮说明型）。
Future<bool?> showConfirm(
  BuildContext context, {
  String? title,
  required String content,
  String confirmText = '确定',
  String? cancelText = '取消',
  bool danger = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => ConfirmDialog(
      title: title,
      content: content,
      confirmText: confirmText,
      cancelText: cancelText,
      danger: danger,
    ),
  );
}
