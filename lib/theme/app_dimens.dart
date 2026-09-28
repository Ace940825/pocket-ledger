// 口袋账本 · 尺寸令牌（4px 基准间距 + 圆角 + 阴影 + 断点）
// 落点：lib/theme/app_dimens.dart
//
// 取用：Padding(padding: EdgeInsets.all(AppDimens.lg))

import 'package:flutter/material.dart';

/// 间距（4px 基准）
@immutable
class AppDimens {
  const AppDimens._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0; // 页面安全边距 / 弹窗内边距
  static const double space3xl = 32.0;
  static const double space4xl = 40.0;

  // 圆角
  static const double radiusTile = 17.0; // 分类磁贴
  static const double radiusCard = 16.0; // 卡 / 分组
  static const double radiusSheet = 30.0; // 弹窗顶
  static const double radiusKey = 14.0; // 数字键
  static const double radiusChip = 999.0; // 药丸标签

  // 布局
  static const double screenPadding = 24.0; // 安全边距
  static const double sheetHandleW = 36.0; // 拖拽条宽
  static const double sheetHandleH = 4.0;
  static const double minTouch = 44.0; // 最小触控区（AA）

  // 动效
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 420);

  // 屏幕断点（逻辑像素）
  static const double bpSmall = 320.0;
  static const double bpMedium = 375.0;
  static const double bpLarge = 414.0;
  static const double bpXLarge = 430.0;

  /// 按宽度返回安全边距（窄屏收紧，宽屏放宽）
  static double responsivePadding(double width) {
    if (width < bpMedium) return 16.0;
    if (width < bpLarge) return screenPadding;
    return 28.0;
  }
}

/// 阴影令牌（低透明暖色，避免冷黑阴影破坏暖纸调性）
@immutable
class AppShadows {
  const AppShadows._();

  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x0F605034), blurRadius: 8, offset: Offset(0, 2)),
  ];
  static const List<BoxShadow> md = [
    BoxShadow(color: Color(0x1F605034), blurRadius: 30, offset: Offset(0, 10)),
  ];
  static const List<BoxShadow> sage = [
    BoxShadow(color: Color(0x667C9E72), blurRadius: 18, offset: Offset(0, 8)),
  ];
}
