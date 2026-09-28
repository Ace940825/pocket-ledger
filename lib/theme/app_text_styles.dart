// 口袋账本 · 文字令牌（统一字族 + 7 级字号阶梯）
// 落点：lib/theme/app_text_styles.dart
//
// 取用：Text('账单模板', style: AppTextStyles.title)
// 字族：Noto Sans SC（安卓需加入 pubspec 字体；iOS 回退 PingFang SC）。
//
// 【暗色适配铁律 · 本次灰度验证修正】
//   本文件只定义“排版”，不内置任何颜色——颜色一律由主题注入：
//   · 走 ThemeData.textTheme 的角色样式，自动获得 onSurface 色；
//   · 直接使用 AppTextStyles.xxx 时，必须显式补色：
//       AppTextStyles.title.copyWith(color: scheme.onSurface)          // 主文字
//       AppTextStyles.caption.copyWith(color: scheme.onSurfaceVariant) // 次要/弱化
//   若在此硬编码 ink/ink2/ink3（浅色墨阶），暗色主题下会变成深字压深底、
//   几乎不可读——这正是本页灰度验证实测暴露的问题。

import 'package:flutter/material.dart';

/// 统一字族
class AppTypography {
  const AppTypography._();

  /// 主字族（需在 pubspec.yaml 注册字体文件）
  static const String fontFamily = 'Noto Sans SC';

  /// 回退栈：iOS→PingFang，鸿蒙→HarmonyOS，小米→MiSans，其余→system
  static const List<String> fontFamilyFallback = [
    'PingFang SC',
    'HarmonyOS Sans SC',
    'MiSans',
    'system-ui',
    'sans-serif',
  ];
}

/// 字号阶梯与语义样式（唯一事实来源；仅排版，无颜色）
@immutable
class AppTextStyles {
  const AppTextStyles._();

  static const _base = TextStyle(
    fontFamily: AppTypography.fontFamily,
    fontFamilyFallback: AppTypography.fontFamilyFallback,
  );

  /// 金额数字（等宽数字，避免跳动）
  static final display = _base.copyWith(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    height: 1.1,
    letterSpacing: 0.5,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static final titleL = _base.copyWith(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    height: 1.25,
    letterSpacing: 0.4,
  );

  static final title = _base.copyWith(
    fontSize: 17,
    fontWeight: FontWeight.w800,
    height: 1.3,
    letterSpacing: 0.3,
  );

  static final bodyL = _base.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );

  static final body = _base.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.6,
  );

  static final caption = _base.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.6,
  );

  static final micro = _base.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0.2,
  );

  /// 组装 Material TextTheme（供 ThemeData.textTheme 复用，颜色由主题注入）
  static TextTheme get textTheme => TextTheme(
        displayLarge: display,
        headlineMedium: titleL,
        titleMedium: title,
        bodyLarge: bodyL,
        bodyMedium: body,
        bodySmall: caption,
        labelSmall: micro,
      );
}
