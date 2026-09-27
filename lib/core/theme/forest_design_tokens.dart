/// 森林手账（Forest Journal）设计 token v2 —— 对应 forest-design-tokens.json
///
/// 维度：配色 / 尺寸 / 质感 / 纹理。命名与取值与 JSON 完全一致，可直接替换或并入 app_colors.dart。
/// 本文件为「数据集合」，不含任何业务逻辑；插画资产（IP 角色）不在此列。
/// 核心变化：新增 sage（鼠尾草绿渐变主卡系），按钮用 primary 深绿实色、卡片用 sage 浅绿渐变。

import 'package:flutter/material.dart';

// ───────────────────────── 配色 Color ─────────────────────────

/// 背景色
class ForestBg {
  static const Color paper = Color(0xFFFBF6EA); // 主纸底（暖米黄）
  static const Color sunken = Color(0xFFF3EAD8); // 次级/分区/输入框底（深沙）
  static const Color raised = Color(0xFFFFFDF8); // 弹层/浮起（近白暖）
}

/// 卡片表面
class ForestSurface {
  static const Color card = Color(0xFFFFFCF5); // 奶油卡面
  static const Color cardAlt = Color(0xFFF6EFE0); // 次级卡面
  static const Color raised = Color(0xFFFFFDF8); // 弹层/浮起（近白暖，同 ForestBg.raised）
}

/// 森林绿（用于按钮 / 图标 / 强调实色）
class ForestGreen {
  static const Color deep = Color(0xFF2E6B49); // 最深，浅绿底上的文字/描边强调
  static const Color cta = Color(0xFF3C8A60); // 深绿，按钮 / FAB
  static const Color brand = Color(0xFF4FAE80); // 草绿，图标 / 插画 / 主色点缀
  static const Color soft = Color(0xFFE6F2E9); // 浅绿底（选中态）
  static const Color softBorder = Color(0xFFBFE0C9); // 浅绿描边
  static const Color label =
      Color(0xFF557E4C); // 中深绿 editorial 标签（同 ForestSage.label）
}

/// 鼠尾草绿渐变主卡系（页面主色，三档：浅 / 中 / 深）
class ForestSage {
  static const Color ink = Color(0xFF2E5B39); // 深绿墨字（绿卡上的文字）
  static const Color label = Color(0xFF557E4C); // 中深绿 editorial 标签

  // 三档渐变停靠色（左上 → 右下，150°）
  static const List<Color> stopLight = <Color>[
    Color(0xFFEAF3DD),
    Color(0xFFD7E8C4),
    Color(0xFFC2DEA8),
  ]; // 浅档：预算引导卡
  static const List<Color> stopMid = <Color>[
    Color(0xFFE3EFD4),
    Color(0xFFC9E2B4),
    Color(0xFFAED494),
  ]; // 中档：本月结余卡
  static const List<Color> stopDeep = <Color>[
    Color(0xFFD6E8C4),
    Color(0xFFBAD9A0),
    Color(0xFF9ECB80),
  ]; // 深档：净资产卡

  // 按钮渐变停靠色（brand → cta → deep）
  static const List<Color> button = <Color>[
    Color(0xFF4FAE80),
    Color(0xFF3C8A60),
    Color(0xFF2E6B49),
  ];
}

/// 语义色（保留国内记账约定：收入绿 / 支出红）
class ForestSemantic {
  static const Color income = Color(0xFF2FA56B); // 收入（绿）
  static const Color expense = Color(0xFFE2675E); // 支出（暖珊瑚红，非纯红）
  static const Color transfer = Color(0xFF8C9A86); // 转账（中性灰绿）
}

/// 暖调中性（无纯黑纯白）
class ForestNeutral {
  static const Color textPrimary = Color(0xFF2C3329);
  static const Color textSecondary = Color(0xFF6A7263);
  static const Color textTertiary = Color(0xFF9AA091);
  static const Color onSage = Color(0xFF2E5B39); // 绿卡上的文字
  static const Color onGreen = Color(0xFFFFFFFF); // 绿色按钮上的文字
  static const Color hairline = Color(0xFFECE2D0); // 发丝线/描边
  static const Color hairlineStrong = Color(0xFFDDD0B8);
  static const Color hairlineOnSage =
      Color(0x2E5B3929); // 绿卡内深绿发丝线 rgba(46,91,57,.16)
  static const Color deepInk =
      Color(0xFF3E443A); // 钢笔线稿图标色（A3 设计稿 .chip .ci / 深墨）
}

/// 点缀（editorial 标签 / 进度 / 能量）
class ForestAccent {
  static const Color gold = Color(0xFFC9A24B); // 暖金（标签、进度、等级）
  static const Color sun = Color(0xFFF2C94C); // 暖阳黄（能量/签到）
  static const Color clay = Color(0xFFD98C5F); // 陶土橙（偶尔点缀）
}

// ───────────────────────── 尺寸 Size ─────────────────────────

/// 间距（4pt 基准）
class ForestSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double section = 48;
}

/// 圆角（大圆角奶油卡）
class ForestRadius {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 22;
  static const double xl = 28;
  static const double pill = 999;
}

/// 字号（px）
class ForestFont {
  static const double display = 44; // 结余大数字
  static const double headline = 24; // 页标题
  static const double title = 18; // 卡标题
  static const double body = 15; // 正文
  static const double bodySm = 13; // 次要
  static const double label = 11; // editorial 大写标签（letterSpacing 0.12em）
  static const double caption = 12;
}

/// 图标 / 触控
class ForestIcon {
  static const double sm = 20;
  static const double md = 24;
  static const double lg = 32;
  static const double categoryTile = 56; // 圆形分类卡直径
  static const double fab = 56; // FAB 直径
}

// ───────────────────────── 质感 Material ─────────────────────────

/// 阴影（几乎无阴影，靠色阶 + 极浅描边；shadow 用绿/暖墨色低透明度）
class ForestElevation {
  static const List<BoxShadow> flat = <BoxShadow>[];
  static const List<BoxShadow> xs = <BoxShadow>[
    BoxShadow(color: Color(0x0B2C3329), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> sm = <BoxShadow>[
    BoxShadow(color: Color(0x0D2C3329), blurRadius: 8, offset: Offset(0, 2)),
  ];
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(color: Color(0x0F2C3329), blurRadius: 16, offset: Offset(0, 4)),
  ];
  static const List<BoxShadow> float = <BoxShadow>[
    BoxShadow(color: Color(0x473C8A60), blurRadius: 18, offset: Offset(0, 6)),
  ];
  static const List<BoxShadow> sheet = <BoxShadow>[
    BoxShadow(color: Color(0x1A2C3329), blurRadius: 24, offset: Offset(0, -4)),
  ];
}

/// 透明度
class ForestOpacity {
  static const double scrim = 0.32; // 底部弹层遮罩（暖暗）
  static const double disabled = 0.40;
  static const double tint = 0.10; // 选中绿底 alpha
  static const double press = 0.06; // 按压叠加
  static const double grain = 0.05; // 纸纹
  static const double leafWatermark = 0.04; // 叶影水印
}

/// 层级 z
class ForestLayer {
  static const int base = 0;
  static const int card = 1;
  static const int sticky = 10; // AppBar
  static const int fab = 20;
  static const int sheet = 50;
  static const int toast = 90;
  static const int modal = 100;
}

// ───────────────────────── 纹理 Texture ─────────────────────────

/// 纹理为声明式描述，落地方式见 forest-design-tokens.json 的 texture 段：
/// - grain：SVG feTurbulence 噪点（opacity 0.05, multiply）
/// - dots：2px 圆点阵（opacity 0.03, 暖色）
/// - leaf：角落淡叶影水印（opacity 0.04）
/// Flutter 落地建议：GrainOverlay 用 CustomPaint/ShaderMask 或预渲染 WebP；
/// sage 卡片用 ForestSage.stopXxx 三色 LinearGradient(150°, 左上→右下)，文字用 ink，
/// 仅保留 elevation.card 极浅暖墨，不做强投影。

// ───────────────────────── 便捷渐变工厂 ─────────────────────────

/// 鼠尾草绿主卡渐变（150° 左上→右下），直接给 Container.decoration 用
class ForestGradients {
  /// 设计稿 --sageGrad：linear-gradient(135deg,#93BF9A,#5F9A6E)。
  /// 选中态专用（Tab 指示器/分类选中卡），白字对比达标；三档浅粉彩渐变
  /// （sageLight/Mid/Deep）压白字会发糊，勿用于选中态。
  static const LinearGradient sage = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF93BF9A), Color(0xFF5F9A6E)],
  );

  static const LinearGradient sageLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: <double>[0.0, 0.6, 1.0],
    colors: ForestSage.stopLight,
  );
  static const LinearGradient sageMid = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: <double>[0.0, 0.55, 1.0],
    colors: ForestSage.stopMid,
  );
  static const LinearGradient sageDeep = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: <double>[0.0, 0.55, 1.0],
    colors: ForestSage.stopDeep,
  );
  static const LinearGradient button = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: <double>[0.0, 0.55, 1.0],
    colors: ForestSage.button,
  );
}
