import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'line_icon_map.dart';

/// 颜色选择圆点：选中态加粗描边 + 对勾，默认色用「自动」星星图标。
///
/// 抽自添加/编辑分类页的逐字节相同私有实现，统一颜色选择交互。
///
/// 2026-10-16 第 38 批：色板改横向滚动一排（可左滑看更多色），圆点
/// 40→32、图标 20→16；外侧 6px 透明 padding 保住 44px 触控命中区
/// （AppDimens.minTouch），缩小视觉不缩小可点区域。
class ColorChip extends StatelessWidget {
  const ColorChip({
    super.key,
    required this.selected,
    required this.color,
    required this.onTap,
    this.isDefault = false,
  });

  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final bool isDefault;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isDefault ? AppPalette.surfaceLight : color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? context.forest.onSurface
                  : context.forest.outline,
              width: selected ? 2.5 : 1,
            ),
          ),
          child: isDefault
              ? LineGlyph(
                  Icons.auto_awesome,
                  color: selected
                      ? context.forest.onSurface
                      : context.forest.onSurfaceVariant,
                  size: 16,
                )
              : (selected
                  ? LineGlyph(
                      Icons.check,
                      color: context.forest.onPrimary,
                      size: 16,
                    )
                  : null),
        ),
      ),
    );
  }
}
