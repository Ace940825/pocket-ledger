import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimens.dart';

/// 应用主题。Material 3，iOS 上通过平台自适应的转场与滚动物理保持原生手感。
abstract final class AppTheme {
  static ThemeData light() => _base(Brightness.light);

  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF121417) : AppColors.surfaceLight,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor:
            isDark ? const Color(0xFF121417) : AppColors.surfaceLight,
        foregroundColor: isDark ? Colors.white : AppColors.textPrimary,
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      // Flutter 3.24 中卡片主题类仍为 CardTheme（CardThemeData 自 3.27 起才引入）
      cardTheme: CardTheme(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          side: BorderSide(
            color: isDark ? const Color(0xFF2A2E33) : AppColors.divider,
          ),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppDimens.spaceLg,
          vertical: AppDimens.spaceXs,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1B1F24) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceLg,
          vertical: AppDimens.spaceMd,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF2A2E33) : AppColors.divider,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF121417) : Colors.white,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((Set<WidgetState> states) {
          final bool selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.primary : AppColors.textTertiary,
          );
        }),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? const Color(0xFF2A2E33) : AppColors.divider,
        space: 0,
        thickness: 0.5,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        ),
      ),
      // iPhone 优先：iOS / macOS 用原生 Cupertino 转场（右滑返回、横向推入），
      // Android 保持 Material 默认，互不影响。
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
