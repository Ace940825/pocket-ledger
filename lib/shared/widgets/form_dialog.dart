import 'package:flutter/material.dart';
import 'package:pocket_ledger/core/theme/forest_design_tokens.dart';

import '../../theme/app_dimens.dart';
import '../../theme/app_theme.dart';

/// 统一表单弹窗（全应用）。
///
/// 与 [ConfirmDialog] 同属对话框家族：固定圆角 [AppDimens.radiusCard]、语义化
/// 按钮（取消灰 / 确认绿，`danger` 时红）。区别在 [body] 槽位承载多字段表单
/// widget（取代各页手搓的 `AlertDialog` 多字段弹窗）。
///
/// 调用约定沿用各页现有 `showDialog<bool>` + `StatefulBuilder` 结构，仅把
/// `AlertDialog(...)` 换成 `FormDialog(...)`，字段 widget 原样搬入 [body]，
/// 确认按钮一律 `pop(true)`（字段校验由弹窗关闭后页面侧统一处理，与本壳解耦）。
///
/// 若弹窗内需要在确认前做字段校验，可传 [onBeforeConfirm]；返回 `false` 时
/// 拦截关闭（如 [showTextInput] 的 `validator` 语义）。
class FormDialog extends StatelessWidget {
  const FormDialog({
    super.key,
    this.title,
    required this.body,
    this.confirmText = '保存',
    this.cancelText = '取消',
    this.danger = false,
    this.onConfirm,
    this.onCancel,
    this.onBeforeConfirm,
  });

  final String? title;
  final Widget body;

  /// 确认按钮文案；默认「保存」。
  final String confirmText;

  /// 取消按钮文案；传 `null` 时不渲染取消按钮（单按钮说明型）。默认「取消」。
  final String? cancelText;
  final bool danger;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  /// 确认前的拦截钩子；返回 `false` 时阻止关闭弹窗（用于弹窗内字段校验）。默认放行。
  final bool Function()? onBeforeConfirm;

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
      content: body,
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
            if (onBeforeConfirm?.call() ?? true) {
              onConfirm?.call();
              Navigator.of(context).pop(true);
            }
          },
          child: Text(confirmText),
        ),
      ],
    );
  }
}

/// 便捷方法：弹出表单弹窗。
///
/// 返回 `true`=确认 / `false`=取消按钮 / `null`=点遮罩关闭。
/// [cancelText] 传 `null` 时不显示取消按钮（单按钮说明型）。
/// [onBeforeConfirm] 用于在确认前做字段校验，返回 `false` 阻止关闭。
Future<bool?> showFormDialog(
  BuildContext context, {
  String? title,
  required Widget body,
  String confirmText = '保存',
  String? cancelText = '取消',
  bool danger = false,
  bool Function()? onBeforeConfirm,
}) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => FormDialog(
      title: title,
      body: body,
      confirmText: confirmText,
      cancelText: cancelText,
      danger: danger,
      onBeforeConfirm: onBeforeConfirm,
    ),
  );
}
