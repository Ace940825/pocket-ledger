import 'package:flutter/material.dart';

import 'package:pocket_ledger/theme/app_dimens.dart';
import 'line_icon_map.dart';

/// 分类类型切换标签（下划线选中态）。
///
/// 抽自分类管理页 / 分类迁移页的逐字节相同私有实现。
class TypeTab extends StatelessWidget {
  const TypeTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = selected
        ? theme.colorScheme.onSurface
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final FontWeight weight = selected ? FontWeight.w600 : FontWeight.normal;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppDimens.sm),
        decoration: BoxDecoration(
          border: selected
              ? Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.onSurface,
                    width: 2.5,
                  ),
                )
              : null,
        ),
        child: Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: weight,
          ),
        ),
      ),
    );
  }
}

/// 分类分组展开箭头：选中态旋转 90°（chevron_right → 朝下）。
///
/// 抽自分类管理页 / 分类迁移页的逐字节相同私有实现。
class ExpandArrow extends StatelessWidget {
  const ExpandArrow({super.key, required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      child: IconButton(
        onPressed: onTap,
        icon: AnimatedRotation(
          turns: expanded ? 0.25 : 0,
          duration: const Duration(milliseconds: 200),
          child: const LineGlyph(Icons.chevron_right, size: 20),
        ),
      ),
    );
  }
}
