/// 森林资产总览卡片主题（从截图提取）
///
/// 基调：鼠尾草/嫩芽绿渐变卡片 + 深橄榄绿文字 + 金琥珀点缀。
/// 用于「资产总览」「森林主题首页卡片」等场景。
library;

import 'package:flutter/material.dart';

// ───────────────────── 背景 ─────────────────────

class ForestAssetBg {
  /// 卡片主渐变：左上角奶油嫩芽 → 右下角鼠尾草深绿
  static const Gradient card = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFFE8F4CC), // light sage cream
      Color(0xFFC6E8AC), // mid sage
      Color(0xFFA8DC8C), // deep sage
    ],
    stops: <double>[0.0, 0.55, 1.0],
  );

  /// 浅色区（标题、按钮底）
  static const Color light = Color(0xFFE8F4CC);

  /// 中色区（内容区）
  static const Color mid = Color(0xFFC6E8AC);

  /// 深色区（右下角）
  static const Color deep = Color(0xFFA8DC8C);

  /// 下沉/分隔背景
  static const Color sunken = Color(0xFFB8DAA0);

  /// 纸面/页面底色（比卡片更暖更淡）
  static const Color paper = Color(0xFFFBF8F0);
}

// ───────────────────── 主色 ─────────────────────

class ForestAssetGreen {
  /// 深橄榄绿：标题、标签、说明文字
  static const Color ink = Color(0xFF4F5F2F);

  /// 森林绿：金额、强调、主操作文字
  static const Color deep = Color(0xFF3A7A3A);

  /// 主按钮/CTA 填充色
  static const Color cta = Color(0xFF4A8A3A);

  /// 浅绿标签底、按钮浅底
  static const Color soft = Color(0xFFD8EEC4);

  /// 更浅的 hover/pressed 底
  static const Color softHover = Color(0xFFCBE8B4);

  /// 主色 12% 透明（通用遮罩）
  static const Color cta12 = Color(0x1F4A8A3A);

  /// 主色 55% 透明（开关轨道等）
  static const Color cta55 = Color(0x8C4A8A3A);
}

// ───────────────────── 点缀色 ─────────────────────

class ForestAssetAccent {
  /// 金币/宝箱主色
  static const Color gold = Color(0xFFF0C244);

  /// 金币深色描边/阴影
  static const Color goldDark = Color(0xFFC79A20);

  /// 琥珀：负债、待还、低优先级强调（图标/填充）
  static const Color amber = Color(0xFFC98A3F);

  /// 琥珀文字：比 amber 深，保证在浅绿底上可读
  static const Color amberText = Color(0xFF9C6828);

  /// 琥珀浅底
  static const Color amberSoft = Color(0xFFF5E6C8);
}

// ───────────────────── 功能色（沿用项目语义） ─────────────────────

class ForestAssetSemantic {
  /// 收入/净资产：森林绿
  static const Color income = Color(0xFF3A7A3A);

  /// 支出：暖陶土红（与森林绿互补，不刺眼）
  static const Color expense = Color(0xFFC85A4A);

  /// 警告/负债：琥珀金
  static const Color warning = Color(0xFFC98A3F);

  /// 错误：比 warning 更沉的红
  static const Color error = Color(0xFFB84A3A);

  /// 成功/激活
  static const Color success = Color(0xFF4A8A3A);

  /// 链接/可点击
  static const Color link = Color(0xFF5A8A3A);
}

// ───────────────────── 文字 ─────────────────────

class ForestAssetText {
  /// 主文字（深橄榄绿）
  static const Color primary = Color(0xFF4F5F2F);

  /// 强调/金额（森林绿）
  static const Color emphasis = Color(0xFF3A7A3A);

  /// 次级文字（降低透明度/明度）
  static const Color secondary = Color(0xFF6B7A4F);

  /// 占位/禁用（最深可降到 #7A8A5A 仍保持同色系，再浅则对比度不足）
  static const Color tertiary = Color(0xFF7A8A5A);

  /// 反白文字（用于深绿按钮）
  static const Color onCta = Color(0xFFFFFFFF);
}

// ───────────────────── 投影 / 边框 ─────────────────────

class ForestAssetElevation {
  /// 卡片投影：暖墨 + 绿调，不写纯黑
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(
      color: Color(0x1A3A4A2A),
      blurRadius: 18,
      offset: Offset(0, 6),
    ),
  ];

  /// 轻投影（按钮、小卡片）
  static const List<BoxShadow> sm = <BoxShadow>[
    BoxShadow(
      color: Color(0x143A4A2A),
      blurRadius: 8,
      offset: Offset(0, 3),
    ),
  ];
}

class ForestAssetBorder {
  static const Color light = Color(0x1A4F5F2F);
  static const Color strong = Color(0x404F5F2F);
}
