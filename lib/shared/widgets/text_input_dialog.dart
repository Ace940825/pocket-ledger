import 'package:flutter/material.dart';

import 'form_dialog.dart';

/// 单字段文本输入弹窗（全应用统一）。
///
/// 返回用户输入并 `trim` 后的文本；取消或校验未过返回 `null`。
/// 与 [showConfirm] 互补：本组件面向「需要用户填一个值」的场景
/// （账户名 / 自定义银行 / 分期改名 等），而非单纯确认。
///
/// 示例：
/// ```dart
/// final String? name = await showTextInput(
///   context,
///   title: '账户名称',
///   initialValue: controller.text,
/// );
/// if (name != null && mounted) { ... }
/// ```
Future<String?> showTextInput(
  BuildContext context, {
  required String title,
  String? hint,
  String? labelText,
  String? initialValue,
  String confirmText = '确定',
  String cancelText = '取消',
  int maxLines = 1,
  TextInputAction? textInputAction,
  String? Function(String)? validator,
}) async {
  final TextEditingController controller =
      TextEditingController(text: initialValue);
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final bool confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => FormDialog(
          title: title,
          confirmText: confirmText,
          cancelText: cancelText,
          onBeforeConfirm: () => formKey.currentState?.validate() ?? true,
          body: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              maxLines: maxLines,
              textInputAction: textInputAction ??
                  (maxLines > 1
                      ? TextInputAction.newline
                      : TextInputAction.done),
              decoration: InputDecoration(
                hintText: hint,
                labelText: labelText,
                border: const OutlineInputBorder(),
              ),
              validator:
                  validator == null ? null : (String? v) => validator(v ?? ''),
            ),
          ),
        ),
      ) ??
      false;

  if (!confirmed) return null;
  final String value = controller.text.trim();
  return value;
}
