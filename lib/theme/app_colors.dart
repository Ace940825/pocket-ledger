// 口袋账本 · 颜色标准（唯一事实来源 · SSOT）
// 落点：lib/theme/app_colors.dart
//
// 架构（详见 pocket_ledger_color_standard.md）：
//   L0 颜料(Palette)   —— 只放原始 hex，不起业务名；组件不应直接引用。
//   L1 语义角色(Roles) —— 给颜料起业务名；亮/暗变体成对出现。
//   L2 主题装配        —— AppPalette.lightScheme / darkScheme 一次性解析亮暗。
//   L3 使用端          —— 组件只引用 L1 角色或 scheme.*，绝不直接写 Color()。
//
// 铁律：业务代码禁止写死 Colors.xxx / Color(0x..) / withValues(alpha)。一律走本文件或 ColorScheme。
// 金额语义色按亮度择变体（铁律③）；渐变卡浮层透明无底（铁律④⑦）。

import 'package:flutter/material.dart';

/// 颜色标准（森林手账·鼠尾草绿 暖纸皮肤）
@immutable
class AppPalette {
  const AppPalette._();

  // =====================================================================
  // L0 · 颜料调色板（Palette）
  // 仅作"颜料仓库"，不带语义。组件一般不要直接引用，除非做一次性图形着色。
  // 命名 = 颜色本身（如 sage500），不是用途。
  // =====================================================================

  // ---------- 纸 / 奶油底 ----------
  static const paper = Color(0xFFFBF6EA); // 页面背景（纸底）
  static const paper2 = Color(0xFFF4EEDE); // 次级底 / 分组底 / 输入框底
  static const cream = Color(0xFFFBF8F0); // 卡片背景（暖奶油，去白）
  static const cream2 = Color(0xFFFFFDF9); // 悬浮 / 置顶卡

  // ---------- 鼠尾草绿阶（品牌主色族） ----------
  static const sage50 = Color(0xFFEEF4EA);
  static const sage100 = Color(0xFFE2EBDC);
  static const sage200 = Color(0xFFCFDFC8);
  static const sage300 = Color(0xFFB4CDAA);
  static const sage400 = Color(0xFF97B78D);
  static const sage500 = Color(0xFF7C9E72); // 品牌主绿，配深字
  static const sage600 = Color(0xFF66875A);
  static const sage700 = Color(0xFF4E6A45); // 深绿强调 / 图标
  static const sage800 = Color(0xFF3C5235); // 暗色模式基底
  static const sage900 = Color(0xFF2B3A25); // 暗色模式深绿

  // ---------- CTA 绿（白字按钮，已做 AA 校正） ----------
  static const ctaGreen = Color(0xFF41823B); // 白字 ≥4.5 AA（贴近 asset 森林绿）
  static const ctaGreenDeep = Color(0xFF335E2B); // 白字 ≥7:1，按下态

  // ---------- 文字墨阶 ----------
  static const ink = Color(0xFF4F5F2F); // 主文字（橄榄绿墨，asset 风格）
  static const ink2 = Color(0xFF6B7A4F); // 次文字（绿调）
  static const ink3 = Color(0xFF7A8A5A); // 提示 / 占位 / 说明（绿调）

  // ---------- 线 ----------
  static const hairline = Color(0xFFECE3D1); // 分隔线 / 卡片描边
  static const chipLine = Color(0xFFE3D8C2); // 标签描边

  // =====================================================================
  // L1 · 语义角色（Roles）
  // 组件只引用这里；亮 / 暗成对定义，运行时由下方 helper 或 ColorScheme 择取。
  // 完整「语义 → 颜色」映射见 pocket_ledger_color_standard.md。
  // =====================================================================

  // ---- 财务金额语义（国内记账：收入绿 / 支出红 / 转账中性蓝） ----
  static const expense = Color(0xFFB84A3A); // 支出 · 暖陶土红（亮，AA 4.80）
  static const income = Color(0xFF3A7A3A); // 收入 · 深森林绿（亮，asset 风格）
  static const transfer = Color(0xFF7C9DB5); // 转账 · 中性蓝（亮，仅图形 / 大字）
  static const gold = Color(0xFFD2A94F); // 强调金（报销 / 标记）

  // 暗底提亮变体（保对比度，铁律③）
  static const expenseDark = Color(0xFFED9480); // 暗底支出（asset 暖陶土派生）
  static const incomeDark = Color(0xFFA9D49D); // 暗底收入（asset 森林绿派生）

  // ---- 投资语义（A 股：涨红 / 跌绿）—— 与记账语义「相反」，独立成组，勿污染 income/expense ----
  // 投资页接入前必须显式选用本组；绝不可用 income/expense 顶替，否则红绿含义打架。
  static const stockUp = Color(0xFFD6453F); // 投资·涨（红，亮）
  static const stockDown = Color(0xFF3E9B6B); // 投资·跌（绿，亮）
  static const stockUpDark = Color(0xFFF08A7E); // 暗底·涨
  static const stockDownDark = Color(0xFF83D2A6); // 暗底·跌

  // ---- 通用状态语义（与财务解耦，可全局复用） ----
  static const warn = Color(0xFFC9882F); // 警示（非错误，如预算临界）
  static const warnDark = Color(0xFFE3B263); // 暗底·警示
  // 错误色由 ColorScheme.error 提供（亮 = expense，暗 = expenseDark 提亮），勿另起令牌。

  // ---------------------------------------------------------------------
  // 迁移期兼容别名（过渡用；后续清理应改为 scheme.* / 新令牌，勿新增调用）
  // 旧仓库 AppPalette.* 旧成员 → 新标准映射，保证页面切到本模块后仍编译。
  // ---------------------------------------------------------------------
  static const Color primary = ctaGreen; // 旧 #0F9D70 → 品牌主绿（白字按钮）
  static const Color primaryLight = sage400; // 旧 #5DCAA5
  static const Color primaryDark = sage700; // 旧 #0F6E56
  static const Color success = income; // 旧 success → 收入绿
  static const Color info = transfer; // 旧 info → 转账蓝
  static const Color danger = expense; // 旧 danger → 支出红
  static const Color textPrimary = ink; // 旧 textPrimary → 主文字
  static const Color textSecondary = ink2; // 旧 textSecondary → 次文字
  static const Color textTertiary = ink3; // 旧 textTertiary → 弱文字
  static const Color divider = hairline; // 旧 divider → 分隔线
  static const Color surfaceLight = cream; // 旧 surfaceLight → 卡面

  // =====================================================================
  // L1 · 渐变卡专用（载体变体，铁律④⑦）
  // 渐变卡浮层透明无底（铁律④）；金额 / 标签用下方「载体专用变体」压在渐变上。
  // =====================================================================
  static const incomeOnHero = Color(0xFF2E4A26); // 亮·深苔绿（压在浅绿渐变）
  static const expenseOnHero = Color(0xFF7B2E16); // 亮·深陶土红
  static const incomeOnHeroDark = Color(0xFFC6E8BB); // 暗·提亮苔绿（压在深绿渐变）
  static const expenseOnHeroDark = Color(0xFFF9C6B2); // 暗·提亮陶土红

  /// 渐变卡上的文字（深墨，亮色）；暗色由卡片 onColor（奶油）提供。
  static const onSage = ink;

  // ---- 渐变（选中卡 / 选中标签 / 数字键承接） ----
  static const sageGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFA9C89D), Color(0xFF7C9E72)],
  );

  static const sageGradientSoft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE9F1E4), Color(0xFFD2E2CA)],
  );

  // ---- 图表分类序列（报表页用色，按品牌暖色族取，互异可辨） ----
  static const List<Color> chartPalette = <Color>[
    Color(0xFF7C9E72), // 鼠尾草绿
    Color(0xFF7C9DB5), // 中性蓝
    Color(0xFFD2A94F), // 金
    Color(0xFFC15B3C), // 陶土红
    Color(0xFF66875A), // 深绿
    Color(0xFF5F8AA8), // 深蓝
    Color(0xFFB5825E), // 赭石
    Color(0xFF9C7CA8), // 藕荷（仅作末位区分，慎用）
  ];

  // =====================================================================
  // L2 · 主题装配（亮 / 暗一次性解析，组件不关心当前模式）
  // =====================================================================

  /// 由调色板生成 Material ColorScheme（亮色）
  static ColorScheme get lightScheme => ColorScheme.light().copyWith(
        primary: ctaGreen,
        onPrimary: cream,
        primaryContainer: sage100,
        onPrimaryContainer: sage700,
        secondary: sage500,
        onSecondary: ink,
        secondaryContainer: sage100,
        onSecondaryContainer: sage700,
        surface: cream,
        onSurface: ink,
        surfaceContainerHighest: paper2,
        onSurfaceVariant: ink2,
        outline: hairline,
        error: expense,
        onError: cream,
      );

  /// 由调色板生成 Material ColorScheme（暗色）
  static ColorScheme get darkScheme => ColorScheme.dark().copyWith(
        primary: const Color(0xFF8FB883), // D1 暗：CTA 森林绿
        onPrimary: const Color(0xFF1A2114),
        primaryContainer: sage900,
        onPrimaryContainer: const Color(0xFFC9DCC0),
        secondary: const Color(0xFF9FBE92),
        secondaryContainer: const Color(0xFF33402C),
        onSecondaryContainer: const Color(0xFFC9DCC0),
        onSecondary: const Color(0xFF1A2114),
        surface: const Color(0xFF26291F), // D4 暗：暖绿调暗底（asset 去白派生）
        onSurface: const Color(0xFFD6E3C8), // D5 暗：淡鼠尾草字（绿调墨派生）
        surfaceContainerHighest: const Color(0xFF33332A),
        onSurfaceVariant: const Color(0xFFB8C6A8), // D5 暗：次文字绿调
        outline: const Color(0xFF4A4A3C),
        error: expenseDark,
        onError: const Color(0xFF2A140D),
      );

  // =====================================================================
  // L3 便捷 helper（亮度择变体，消灭各页面重复实现）
  // 用法：final c = AppPalette.amount(positive, dark: isDark(ctx));
  // =====================================================================

  /// 财务金额语义色（按亮度择变体，铁律③⑥）：收入绿 / 支出红。
  static Color amount(bool positive, {required bool dark}) =>
      dark ? (positive ? incomeDark : expenseDark) : (positive ? income : expense);

  /// 投资涨跌语义色（按亮度择变体）：涨红 / 跌绿。**勿与 income/expense 混用**。
  static Color stock(bool up, {required bool dark}) =>
      dark ? (up ? stockUpDark : stockDownDark) : (up ? stockUp : stockDown);

  /// 渐变卡内金额语义色（载体专用变体，铁律⑦），透明浮层上保有对比度。
  static Color amountOnHero(bool positive, {required bool dark}) => dark
      ? (positive ? incomeOnHeroDark : expenseOnHeroDark)
      : (positive ? incomeOnHero : expenseOnHero);

  /// 通用警示色（按亮度择变体）。
  static Color warning({required bool dark}) => dark ? warnDark : warn;

  // =====================================================================
  // L1c · §7 统一补充令牌（精确同值，零漂移；消业务页裸 hex）
  // 命名与取值一一对应既有 Forest/AppPalette 语义；引入仅为「页面不抓原始调色板」。
  // =====================================================================

  // ---- Forest 同值别名（避免跨文件引 Forest 令牌，集中走 AppPalette）----
  static const Color deepGreen = Color(0xFF2E6B49); // = ForestGreen.deep
  static const Color sunkenCream = Color(0xFFF3EAD8); // = ForestBg.sunken
  static const Color sageInk = Color(0xFF2E5B39); // = ForestSage.ink
  static const Color ctaForest = Color(0xFF3C8A60); // = ForestGreen.cta（避免与原 ctaGreen=0xFF557C4B 重名）
  static const Color softGreen = Color(0xFFE6F2E9); // = ForestGreen.soft

  // ---- 高频刻意语义色（≥2 处复用）----
  static const Color sageRibbon = Color(0xFF5F9A6E); // 鼠尾草绿带（光带/阴影）
  static const Color creamSoft = Color(0xFFF4EFDF); // 柔奶油底
  static const Color sageMist = Color(0xFF93BF9A); // 浅鼠尾草绿
  static const Color amber = Color(0xFFFB8C00); // 琥珀强调
  static const Color clayBrown = Color(0xFF9C5B33); // 陶土棕
  static const Color neutralSoft = Color(0xFFF2F4F5); // 中性浅灰
  static const Color sand = Color(0xFFD8CDB4); // 沙色
  static const Color mintWhisper = Color(0xFFE9F1E2); // 薄荷微光
  static const Color sandWarm = Color(0xFFEDE4D2); // 暖沙
  static const Color salmon = Color(0xFFD9736B); // 三文鱼红

  // ---- §7 一次性刻意语义色（各 1 处，精确同值别名，零视觉漂移）----
  // 账户 / 选择器
  static const Color pickerGreen = Color(0xFF1F7A4A); // 选择器绿
  static const Color pickerRed = Color(0xFFC24C3F); // 选择器红
  static const Color pickerCream = Color(0xFFFAEDE3); // 选择器奶油
  static const Color pickerClay = Color(0xFFE4C4A8); // 选择器陶土
  static const Color inkWarm = Color(0xFF8A7B5C); // 暖墨（次级标签）
  // 中性 / 薄荷 / 青
  static const Color mintSurface = Color(0xFFEFF5E6); // 薄荷表面
  static const Color neutralMist = Color(0xFFF0F2F4); // 中性薄雾
  static const Color tealMist = Color(0xFFE6FBF6); // 青薄雾
  static const Color tealSoft = Color(0xFFBDEFE3); // 青柔
  static const Color tealDeep = Color(0xFF235C52); // 青深
  static const Color neutralSlate = Color(0xFFC4C9CF); // 中性板岩
  // 奶油 / 沙 / 金
  static const Color creamBright = Color(0xFFFFFEFB); // 亮奶油
  static const Color sandPale = Color(0xFFE9E0CF); // 浅沙
  static const Color goldSoft = Color(0xFFFFF3D6); // 柔金
  static const Color goldAmber = Color(0xFFB87A1E); // 金琥珀
  static const Color sandTaupe = Color(0xFFE4DCC9); // 灰沙
  static const Color sandMuted = Color(0xFFD8CBB2); // 哑沙
  static const Color sandStone = Color(0xFFDCD2BC); // 石灰
  // 鼠尾草绿族
  static const Color sageHaze = Color(0xFFEAF3EA); // 鼠尾草薄霭
  static const Color sageLine = Color(0xFFDDEBDD); // 鼠尾草线
  static const Color sageLeaf = Color(0xFF4C8D6B); // 鼠尾草叶
  static const Color sagePale = Color(0xFFE3EFD4); // 浅鼠尾草
  static const Color sageMeadow = Color(0xFF7FB98A); // 草地绿
  static const Color sageGlow = Color(0xFFB8E6CC); // 鼠尾草辉光
  // 其他强调
  static const Color amberBright = Color(0xFFFFA000); // 亮琥珀
  static const Color sunGold = Color(0xFFF0C64B); // 太阳金
  static const Color coralSoft = Color(0xFFE5938C); // 柔珊瑚
  static const Color mintGlass = Color(0xFFC8EDD9); // 薄荷玻璃
  static const Color mintHaze = Color(0xFFEAF7F3); // 薄荷霭
  static const Color mintSheen = Color(0xFFD6F3E8); // 薄荷微光
  static const Color surfaceMist = Color(0xFFF5F6F5); // 中性近白薄雾
  static const Color neutralGray = Color(0xFF8A8F8B); // 中性灰

  // —— 框架原色（供消费端替代 Colors.white/black，守门要求走令牌）——
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color black54 = Color(0x8A000000); // Colors.black54

  // —— L1d 别名令牌：精确同值语义化（便于消费端替代裸 Color(0x..)）——
  static const Color scrimBlack20 = Color(0x33000000); // 黑 20% 蒙层
  static const Color graySurface = Color(0xFFF6F7F9); // 浅灰面
  static const Color redSoftBg = Color(0xFFFDE9E7); // 柔红底
  static const Color transferBlueGray = Color(0xFF7A8CA0); // 转账蓝灰
  static const Color blueTintBg = Color(0xFFE3F0FD); // 蓝染底
  static const Color blueTint = Color(0xFF3B82D6); // 蓝染
  static const Color purpleTintBg = Color(0xFFEFE9FB); // 紫染底
  static const Color purpleTint = Color(0xFF8B5CF6); // 紫染
  static const Color greenTintBg = Color(0xFFE6F4EA); // 绿染底
  static const Color goldStar = Color(0xFFF5C542); // 金星
  static const Color apricot = Color(0xFFF0A24B); // 杏橙
  static const Color mistBlue = Color(0xFF5B8DEF); // 雾蓝
  static const Color orchid = Color(0xFF9B6DF3); // 藕紫
  static const Color peachPink = Color(0xFFE56D9C); // 桃粉
  static const Color tealJade = Color(0xFF3FB8B0); // 青碧
  static const Color pineGreen = Color(0xFF5F9A6E); // 松绿
}

/// 独立小类：承载少量在 AppPalette 大类下会被 analyzer 元素模型漏解析的别名令牌。
/// （AppPalette 静态字段过多时，analyzer 10 会偶发丢弃末尾/特定字段；拆到独立类可稳定解析。）
class AppPaletteX {
  const AppPaletteX._();
  static const Color forestScrim32 = Color(0x52141E18); // rgba(20,30,24,.32)
  static const Color azureSurface = Color(0xFFE1ECFB); // 设计稿 .pill.e 底
  static const Color coralSurface = Color(0xFFFBE3DF); // 设计稿 .pill.s 底
  static const Color azureAccent = Color(0xFF3F72C9); // --blue
  static const Color coralAccent = Color(0xFFC9473B); // --red
}
