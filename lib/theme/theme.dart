// 口袋账本 · 主题模块桶文件
// 落点：lib/theme/theme.dart
//
// 一行引入全部令牌：
//   import 'package:pocket_ledger/theme/theme.dart';
//
// 业务代码取用约定：
//   颜色   → AppColors.xxx           或  context.colors.primary (Material 语义)
//   文字   → AppTextStyles.xxx
//   尺寸   → AppDimens.xxx / AppShadows.xxx
//   图标   → AppIcons.xxx
//   非M令牌→ context.app.xxx  (渐变/阴影/圆角)
//   主题   → AppThemeData.light / .dark

export 'app_colors.dart';
export 'app_text_styles.dart';
export 'app_dimens.dart';
export 'app_icons.dart';
export 'app_theme.dart';
