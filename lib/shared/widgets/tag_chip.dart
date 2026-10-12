import 'package:flutter/material.dart';

import '../../core/theme/forest_design_tokens.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_theme.dart';

/// 标签芯片（全应用统一）：选中 = 鼠尾草渐变 + 墨绿字；未选 = 沙底 + 发丝线。
///
/// 视觉对齐 [TagSheet] 既有设计，零漂移；抽出后让记一笔 / 报销 / 流水详情 /
/// 筛选页的标签选择态一致。可选 [color] 前置圆点（标签分组色），[deletable] 出删除钮。
class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.color,
    this.deletable = false,
    this.onDeleted,
    this.showHash = true,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  /// 前置色点（标签分组色）；提供时隐藏 `#` 前缀。
  final Color? color;

  /// 是否在右侧显示删除图标（点击触发 [onDeleted]）。
  final bool deletable;
  final VoidCallback? onDeleted;

  /// 未选且未提供 [color] 时，标签前显示 `#` 前缀。
  final bool showHash;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final List<Widget> leading = <Widget>[
      if (showHash && color == null)
        Text(
          '#',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? ForestSage.ink : ForestGreen.deep,
          ),
        ),
      if (color != null) ...<Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
      ],
    ];

    final List<Widget> children = <Widget>[
      ...leading,
      Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          color: selected ? ForestSage.ink : scheme.onSurface,
        ),
      ),
      if (deletable)
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: InkWell(
            onTap: onDeleted,
            borderRadius: BorderRadius.circular(AppDimens.radiusChip),
            child: Icon(
              Icons.close,
              size: 14,
              color: selected ? ForestSage.ink : scheme.onSurfaceVariant,
            ),
          ),
        ),
    ];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.radiusChip),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          gradient: selected ? context.app.sageGradientMid : null,
          color: selected ? null : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppDimens.radiusChip),
          border: selected ? null : Border.all(color: scheme.outline),
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: AppPalette.stockDown.withValues(alpha: 0.165),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}
