/// 统一的尺寸与圆角常量，避免各处硬编码魔法数字。
abstract final class AppDimens {
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 24;
  static const double spaceXxl = 32;

  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;

  /// 列表卡片高度（流水行）
  static const double listTileHeight = 68;

  /// 响应式断点：移动 / 平板 / 桌面
  static const double breakpointMobile = 650;
  static const double breakpointTablet = 1100;
}
