import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'line_icon_map.dart';

/// 颜色选择圆点：选中态加粗描边 + 对勾，默认色用「自动」星星图标。
///
/// 抽自添加/编辑分类页的逐字节相同私有实现，统一颜色选择交互。
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
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDefault ? AppPalette.surfaceLight : color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.outline,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: isDefault
            ? LineGlyph(
                Icons.auto_awesome,
                color: selected
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                size: 20,
              )
            : (selected
                ? LineGlyph(
                    Icons.check,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 20,
                  )
                : null),
      ),
    );
  }
}
