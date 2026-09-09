import 'package:flutter/material.dart';

/// 应用配色。
///
/// 财务场景的配色约定（重要）：
/// - **记账**：收入 = 绿色，支出 = 红色（国内记账 App 主流认知）
/// - **投资**：涨 = 红色，跌 = 绿色（A 股习惯，与记账场景相反）
///
/// 因此本文件同时提供 [income] / [expense] 与 [stockUp] / [stockDown] 两组语义色，
/// 调用方必须按场景正确选取，不可混用。
abstract final class AppColors {
  /// 品牌主色（沉稳青绿，传达"财务稳健"）
  static const Color primary = Color(0xFF0F9D70);

  static const Color primaryLight = Color(0xFF5DCAA5);
  static const Color primaryDark = Color(0xFF0F6E56);

  /// 记账：收入
  static const Color income = Color(0xFF12B886);

  /// 记账：支出
  static const Color expense = Color(0xFFE5484D);

  /// 记账：转账（中性蓝，既不增也不减资产）
  static const Color transfer = Color(0xFF378ADD);

  /// 投资：涨（A 股红）
  static const Color stockUp = Color(0xFFE5484D);

  /// 投资：跌（A 股绿）
  static const Color stockDown = Color(0xFF12B886);

  static const Color warning = Color(0xFFEF9F27);
  static const Color danger = Color(0xFFE5484D);
  static const Color success = Color(0xFF12B886);
  static const Color info = Color(0xFF378ADD);

  /// 中性灰阶
  static const Color textPrimary = Color(0xFF1F2328);
  static const Color textSecondary = Color(0xFF5F5E5A);
  static const Color textTertiary = Color(0xFF888780);
  static const Color divider = Color(0xFFE5E3DC);
  static const Color surfaceLight = Color(0xFFFAFAF8);

  /// 图表配色序列，按顺序取用
  static const List<Color> chartPalette = <Color>[
    Color(0xFF0F9D70),
    Color(0xFF378ADD),
    Color(0xFFEF9F27),
    Color(0xFFD4537E),
    Color(0xFF7F77DD),
    Color(0xFF1D9E75),
    Color(0xFFBA7517),
    Color(0xFFE24B4A),
    Color(0xFF639922),
    Color(0xFF888780),
  ];
}
