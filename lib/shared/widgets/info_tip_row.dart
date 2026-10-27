import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'line_icon_map.dart';

/// ⓘ 信息提示行（全应用统一）：奶油底圆角卡 + 左侧 info 图标 + 灰字说明。
///
/// 用于表单 / 详情页的辅助说明（如「快捷属性适用于…」「弹性公式…」）。
/// 文字色走主题 [ColorScheme.onSurfaceVariant]，暗色自动适配；调用方只传说明文案。
class InfoTipRow extends StatelessWidget {
  const InfoTipRow({
    super.key,
    required this.text,
    this.icon = Icons.info_outline,
    this.iconSize = 16,
  });

  final String text;
  final IconData icon;
  final double iconSize;

  @override
  Widget build(BuildContext context) {

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppPalette.surfaceMist,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child:
                LineGlyph(icon, size: iconSize, color: context.forest.onSurfaceVariant),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.forest.onSurfaceVariant,
                    height: 1.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
