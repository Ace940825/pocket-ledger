// 口袋账本 · 主题组装（ThemeExtension + ThemeData）
// 落点：lib/theme/app_theme.dart
//
// 用法：
//   MaterialApp(theme: AppThemeData.light, darkTheme: AppThemeData.dark)
//   取非 Material 令牌：context.app.sageGradient / context.app.shadowSm
//   取 Material 语义色：context.colors.primary

import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'app_dimens.dart';

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
  });

  final Gradient sageGradient;
  final Gradient sageGradientSoft;
  final List<BoxShadow> shadowSm;
  final List<BoxShadow> shadowMd;
  final List<BoxShadow> shadowSage;
  final double radiusSheet;
  final double radiusCard;
  final double radiusTile;
  final double radiusKey;
  final double radiusChip;

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
      BoxShadow(color: Color(0x66000000), blurRadius: 30, offset: Offset(0, 10)),
    ],
    shadowSage: [
      BoxShadow(color: Color(0x667C9E72), blurRadius: 18, offset: Offset(0, 8)),
    ],
    radiusSheet: AppDimens.radiusSheet,
    radiusCard: AppDimens.radiusCard,
    radiusTile: AppDimens.radiusTile,
    radiusKey: AppDimens.radiusKey,
    radiusChip: AppDimens.radiusChip,
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
  }) {
    return AppTheme(
      sageGradient: sageGradient ?? this.sageGradient,
      sageGradientSoft: sageGradientSoft ?? this.sageGradientSoft,
      shadowSm: shadowSm ?? this.shadowSm,
      shadowMd: shadowMd ?? this.shadowMd,
      shadowSage: shadowSage ?? this.shadowSage,
      radiusSheet: radiusSheet ?? this.radiusSheet,
      radiusCard: radiusCard ?? this.radiusCard,
      radiusTile: radiusTile ?? this.radiusTile,
      radiusKey: radiusKey ?? this.radiusKey,
      radiusChip: radiusChip ?? this.radiusChip,
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
        backgroundColor: scheme.surface,
        selectedColor: scheme.secondaryContainer,
        side: BorderSide(color: scheme.outline),
        labelStyle: AppTextStyles.micro,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.md,
          vertical: AppDimens.xs,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(ext.radiusSheet)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppPalette.ctaGreen,
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
