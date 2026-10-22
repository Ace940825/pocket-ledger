// 口袋账本 · 主题组装（ThemeExtension + ThemeData）
// 落点：lib/theme/app_theme.dart
//
// 用法：
//   MaterialApp(theme: AppThemeData.light, darkTheme: AppThemeData.dark)
//   取非 Material 令牌：context.app.sageGradient / context.app.shadowSm
//   取 Material 语义色：context.colors.primary

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_dimens.dart';
import 'app_text_styles.dart';

/// 非 Material 令牌（渐变 / 阴影 / 圆角），随亮度插值
@immutable
class AppTheme extends ThemeExtension<AppTheme> {
  const AppTheme({
    required this.sageGradient,
    required this.sageGradientSoft,
    required this.shadowSm,
    required this.shadowMd,
    required this.shadowSage,
    required this.radiusSheet,
    required this.radiusCard,
    required this.radiusTile,
    required this.radiusKey,
    required this.radiusChip,
    required this.sunken,
    required this.sageGradientMid,
    required this.sageGradientLight,
  });

  final Gradient sageGradient;
  final Gradient sageGradientSoft;
  final Gradient sageGradientMid;
  final Gradient sageGradientLight;
  final List<BoxShadow> shadowSm;
  final List<BoxShadow> shadowMd;
  final List<BoxShadow> shadowSage;
  final double radiusSheet;
  final double radiusCard;
  final double radiusTile;
  final double radiusKey;
  final double radiusChip;
  final Color sunken;

  static const AppTheme light = AppTheme(
    sageGradient: AppPalette.sageGradient,
    sageGradientSoft: AppPalette.sageGradientSoft,
    shadowSm: AppShadows.sm,
    shadowMd: AppShadows.md,
    shadowSage: AppShadows.sage,
    radiusSheet: AppDimens.radiusSheet,
    radiusCard: AppDimens.radiusCard,
    radiusTile: AppDimens.radiusTile,
    radiusKey: AppDimens.radiusKey,
    radiusChip: AppDimens.radiusChip,
    sunken: AppPalette.sunkenCream,
    sageGradientMid: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      stops: <double>[0.0, 0.55, 1.0],
      colors: <Color>[
        Color(0xFFE3EFD4),
        Color(0xFFC9E2B4),
        Color(0xFFAED494),
      ],
    ),
    sageGradientLight: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      stops: <double>[0.0, 0.6, 1.0],
      colors: <Color>[
        Color(0xFFEAF3DD),
        Color(0xFFD7E8C4),
        Color(0xFFC2DEA8),
      ],
    ),
  );

  static const AppTheme dark = AppTheme(
    sageGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF7C9E72), Color(0xFF4E6A45)],
    ),
    sageGradientSoft: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF3C5235), Color(0xFF2B3A25)],
    ),
    shadowSm: [
      BoxShadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 2)),
    ],
    shadowMd: [
      BoxShadow(
        color: Color(0x66000000),
        blurRadius: 30,
        offset: Offset(0, 10),
      ),
    ],
    shadowSage: [
      BoxShadow(color: Color(0x667C9E72), blurRadius: 18, offset: Offset(0, 8)),
    ],
    radiusSheet: AppDimens.radiusSheet,
    radiusCard: AppDimens.radiusCard,
    radiusTile: AppDimens.radiusTile,
    radiusKey: AppDimens.radiusKey,
    radiusChip: AppDimens.radiusChip,
    sunken: Color(0xFF2E3128),
    sageGradientMid: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      stops: <double>[0.0, 0.55, 1.0],
      colors: <Color>[
        Color(0xFF42553A),
        Color(0xFF35452E),
        Color(0xFF2A3823),
      ],
    ),
    sageGradientLight: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      stops: <double>[0.0, 0.6, 1.0],
      colors: <Color>[
        Color(0xFF3A4A33),
        Color(0xFF2F3D29),
        Color(0xFF26331F),
      ],
    ),
  );

  @override
  AppTheme copyWith({
    Gradient? sageGradient,
    Gradient? sageGradientSoft,
    List<BoxShadow>? shadowSm,
    List<BoxShadow>? shadowMd,
    List<BoxShadow>? shadowSage,
    double? radiusSheet,
    double? radiusCard,
    double? radiusTile,
    double? radiusKey,
    double? radiusChip,
    Color? sunken,
    Gradient? sageGradientMid,
    Gradient? sageGradientLight,
  }) {
    return AppTheme(
      sageGradient: sageGradient ?? this.sageGradient,
      sageGradientSoft: sageGradientSoft ?? this.sageGradientSoft,
      sageGradientMid: sageGradientMid ?? this.sageGradientMid,
      sageGradientLight: sageGradientLight ?? this.sageGradientLight,
      shadowSm: shadowSm ?? this.shadowSm,
      shadowMd: shadowMd ?? this.shadowMd,
      shadowSage: shadowSage ?? this.shadowSage,
      radiusSheet: radiusSheet ?? this.radiusSheet,
      radiusCard: radiusCard ?? this.radiusCard,
      radiusTile: radiusTile ?? this.radiusTile,
      radiusKey: radiusKey ?? this.radiusKey,
      radiusChip: radiusChip ?? this.radiusChip,
      sunken: sunken ?? this.sunken,
    );
  }

  @override
  AppTheme lerp(AppTheme? other, double t) {
    if (other is! AppTheme) return this;
    return AppTheme(
      sageGradient: Gradient.lerp(sageGradient, other.sageGradient, t)!,
      sageGradientSoft:
          Gradient.lerp(sageGradientSoft, other.sageGradientSoft, t)!,
      shadowSm: BoxShadow.lerpList(shadowSm, other.shadowSm, t)!,
      shadowMd: BoxShadow.lerpList(shadowMd, other.shadowMd, t)!,
      shadowSage: BoxShadow.lerpList(shadowSage, other.shadowSage, t)!,
      radiusSheet: radiusSheet + (other.radiusSheet - radiusSheet) * t,
      radiusCard: radiusCard + (other.radiusCard - radiusCard) * t,
      radiusTile: radiusTile + (other.radiusTile - radiusTile) * t,
      radiusKey: radiusKey + (other.radiusKey - radiusKey) * t,
      radiusChip: radiusChip + (other.radiusChip - radiusChip) * t,
      sunken: Color.lerp(sunken, other.sunken, t)!,
      sageGradientMid:
          Gradient.lerp(sageGradientMid, other.sageGradientMid, t)!,
      sageGradientLight:
          Gradient.lerp(sageGradientLight, other.sageGradientLight, t)!,
    );
  }
}

/// BuildContext 取用捷径
extension AppThemeX on BuildContext {
  AppTheme get app => Theme.of(this).extension<AppTheme>()!;
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
}

/// 组装亮 / 暗 ThemeData
@immutable
class AppThemeData {
  const AppThemeData._();

  static final ThemeData light =
      _build(AppPalette.lightScheme, AppTheme.light, AppPalette.paper);
  static final ThemeData dark =
      _build(AppPalette.darkScheme, AppTheme.dark, const Color(0xFF1F1F18));

  static ThemeData _build(
    ColorScheme scheme,
    AppTheme ext,
    Color scaffold,
  ) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
    );
    return base.copyWith(
      scaffoldBackgroundColor: scaffold,
      textTheme: AppTextStyles.textTheme.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        // M3 AppBar 在「scrolled under」（含下拉过载）会叠 surfaceTint，
        // 显式关掉保证标题栏任何状态下都透出 scaffold 底色。
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        // 全应用标题统一居中（与报销/借还/退款等自定义居中标题栏一致）。
        centerTitle: true,
        // AppTextStyles.title 本体无颜色（见 app_text_styles.dart 铁律），
        // AppBar 直接采用无色样式时文字会渲染成白色 → 奶油底不可见，
        // 必须在此显式补 onSurface 色。
        titleTextStyle: AppTextStyles.title.copyWith(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ext.radiusCard),
          side: BorderSide(color: scheme.outline),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        // 未选中底色与输入框统一用 surfaceContainerHighest（paper2），与
        // 奶油页面拉开层次；selectedColor 沿用 secondaryContainer（sage100）。
        backgroundColor: scheme.surfaceContainerHighest,
        selectedColor: scheme.secondaryContainer,
        checkmarkColor: scheme.primary,
        side: BorderSide(color: scheme.outline),
        // labelStyle 的 color 必须是 **WidgetStateColor**：chip 内部只对
        // `style.color` 做 `WidgetStateProperty.resolveAs`（chip.dart 1376），
        // 普通 Color / 无色一律透传为 null → 渲染成白字（本项目两次实锤：
        // AppBar titleTextStyle 与本次同步控制页胶囊，2026-10-21）。
        // 未选中取 onSurface（墨色），选中取 onSecondaryContainer（sage700）。
        labelStyle: AppTextStyles.micro.copyWith(
          color: WidgetStateColor.resolveWith((Set<WidgetState> states) {
            final bool selected = states.contains(WidgetState.selected);
            return selected ? scheme.onSecondaryContainer : scheme.onSurface;
          }),
        ),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.md,
          vertical: AppDimens.xs,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        // M3 默认 elevation=1 会让透明 Material 沿全宽形状投影；悬浮卡化
        // （四周留边）后投影会在留边区露出，顶部两角成深色残角（2026-10-14
        // 反馈「还有角」）。归零后弹层立体感由卡片自绘负责。
        elevation: 0,
        // 关掉 M3 路由层自带的拖拽柄（画在透明 Material 顶部、悬浮在遮罩上，
        // 即深色背景上的那条灰柄）：2026-10-14 第 19 批反馈全局移除上下柄。
        showDragHandle: false,
        // 显式清空 M3 默认的 maxWidth: 640 约束（_BottomSheetDefaultsM3）：
        // 宽屏（平板模拟器/折叠屏/桌面）下弹层会被缩到 640dp 居中、
        // 两侧露出深色遮罩（2026-10-14 真机/模拟器反馈「两边有角」）。
        // 本应用为手机优先，弹层一律全宽贴边。
        constraints: const BoxConstraints(),
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(ext.radiusSheet)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size.fromHeight(AppDimens.minTouch),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outline,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.lg,
          vertical: AppDimens.md,
        ),
      ),
      extensions: [ext],
    );
  }
}
