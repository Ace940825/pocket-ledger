import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'line_icon_map.dart';

/// 静态字段标签胶囊（全应用统一）。
///
/// 取代储蓄三页手搭的 `_labelPill` / `_sheetLabelPill`：中性薄雾底 + 居中标签，
/// 可选前置图标（如「¥ 转至」分隔）。亮/暗均沿用 [AppPalette.surfaceMist]，
/// 与原手搭行为一致（暗色下偏亮，待暗色模式整体适配时统一收敛）。
///
/// [dense] = true 用于弹窗内（高度 36 / 圆角 20 / 13px），false 用于页面（46 / 24 / 14px），
/// 与相邻的 [AccountSelectPill] 同高同圆角，保证并排对齐。
class LabelPill extends StatelessWidget {
  const LabelPill({
    super.key,
    required this.label,
    this.icon,
    this.dense = false,
  });

  final String label;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {

    final double height = dense ? 36 : 46;
    final double radius = dense ? 20 : 24;
    final double fontSize = dense ? 13 : 14;
    final double hPadding = dense ? 14 : 16;
    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: hPadding),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppPalette.surfaceMist,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            LineGlyph(icon, size: 14, color: context.forest.onSurfaceVariant),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style:
                TextStyle(fontSize: fontSize, color: context.forest.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
