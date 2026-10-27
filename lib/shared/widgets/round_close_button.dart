import 'package:flutter/material.dart';
import 'package:pocket_ledger/core/theme/forest_design_tokens.dart';

import 'line_icon_map.dart';

/// 圆形关闭按钮（全应用统一）。
///
/// 替代各页手搭的 `_RoundCloseButton` / `_SheetCloseButton` / `_CloseBtn`：
/// 圆形浅底 + 居中 ✕，默认点击关闭当前路由（可用 [onTap] 覆盖）。
///
/// [backgroundColor] 不传时取 `colorScheme.surface`；需要凹陷质感时传入
/// `colorScheme.surfaceContainerHighest`（与全站输入框底色统一）。
class RoundCloseButton extends StatelessWidget {
  const RoundCloseButton({
    super.key,
    this.size = 40,
    this.iconSize,
    this.onTap,
    this.backgroundColor,
  });

  final double size;
  final double? iconSize;
  final VoidCallback? onTap;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {

    return InkWell(
      onTap: onTap ?? () => Navigator.of(context).pop(),
      customBorder: const CircleBorder(),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor ?? context.forest.surface,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: LineGlyph(
          Icons.close,
          size: iconSize ?? size * 0.5,
          color: context.forest.onSurfaceVariant,
        ),
      ),
    );
  }
}
