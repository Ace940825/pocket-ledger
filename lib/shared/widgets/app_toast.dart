import 'package:flutter/material.dart';

import '../../core/theme/forest_design_tokens.dart';

/// 全局统一轻提示。
///
/// - 时长 1.6 秒（短提示），比 SnackBar 默认 4 秒更跟手；
/// - 显示前清空队列：连续点击不会排队叠加，新提示直接替换旧提示；
/// - 样式统一为深墨色浮层（ForestNeutral.deepInk），与设计稿一致。
void showAppToast(
  BuildContext context,
  String message, {
  Duration duration = const Duration(milliseconds: 1600),
}) {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context)
    ..clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: duration,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.only(bottom: 96, left: 16, right: 16),
      backgroundColor: ForestNeutral.deepInk,
    ),
  );
}
