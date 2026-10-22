import 'package:flutter/material.dart';
import 'package:pocket_ledger/core/theme/forest_design_tokens.dart';
import 'package:pocket_ledger/shared/widgets/badge_pill.dart';
import 'package:pocket_ledger/shared/widgets/hairline_card.dart';
import 'package:pocket_ledger/theme/app_colors.dart';
import 'line_icon_map.dart';

/// 设置页「标题 + 副标题 + 可选徽标 + 可选箭头」卡片行（全应用统一）。
///
/// 取代各页手搭的 `_SettingsTile` / `_SettingRow`：默认自带 [HairlineCard]
/// （radius 14、下间距 12），标题 15/w500、副标题 12 走 ColorScheme 暗色自动适配；
/// [badge] 非空时在其右侧显示 [BadgePill]（[badgeColor] 为底色，[badgeTextColor] 可选）。
///
/// 进阶形态（[card] = false 时整行裸露，交给外层容器包卡 + 分隔线）：
/// - [leadingIcon] 非空 → 左侧渲染 38×[scale] 浅绿圆角图标 tile；
/// - [trailing] 非空 → 取代默认 chevron，放置任意右侧控件（Switch / 值胶囊等）；
/// - [labelStyle] / [subStyle] 覆盖默认字号字重（如紧凑列表需要的 14/w700）；
/// - [scale] 整体等比缩放图标 tile 与各间距，支持多机型自适应。
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.label,
    required this.sub,
    this.onTap,
    this.badge,
    this.badgeColor,
    this.badgeTextColor,
    this.badgeRadius = 5,
    this.leadingIcon,
    this.trailing,
    this.scale = 1.0,
    this.card = true,
    this.labelStyle,
    this.subStyle,
  });

  final String label;
  final String sub;
  final VoidCallback? onTap;
  final String? badge;
  final Color? badgeColor;
  final Color? badgeTextColor;
  final double badgeRadius;
  final Widget? leadingIcon;
  final Widget? trailing;
  final double scale;
  final bool card;
  final TextStyle? labelStyle;
  final TextStyle? subStyle;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextStyle resolvedLabel = labelStyle ??
        TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: scheme.onSurface,
        );
    final TextStyle resolvedSub = subStyle ??
        TextStyle(
          fontSize: 12,
          color: scheme.onSurfaceVariant,
        );

    final Widget row = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 14 * scale,
        vertical: 13 * scale,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (leadingIcon != null) ...<Widget>[
            Container(
              width: 38 * scale,
              height: 38 * scale,
              decoration: BoxDecoration(
                color: ForestGreen.soft,
                borderRadius: BorderRadius.circular(11 * scale),
              ),
              alignment: Alignment.center,
              child: leadingIcon,
            ),
            SizedBox(width: 12 * scale),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(label, style: resolvedLabel),
                    ),
                    if (badge != null) ...<Widget>[
                      SizedBox(width: 6 * scale),
                      BadgePill(
                        text: badge!,
                        color: badgeColor ?? scheme.primary,
                        textColor: badgeTextColor,
                        radius: badgeRadius,
                        scale: scale,
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 3 * scale),
                Text(
                  sub,
                  style: resolvedSub,
                ),
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[
            SizedBox(width: 8 * scale),
            trailing!,
          ] else if (onTap != null)
            const LineGlyph(Icons.chevron_right,
                color: AppPalette.neutralSlate,),
        ],
      ),
    );

    if (!card) return row;
    return HairlineCard(
      margin: const EdgeInsets.only(bottom: 12),
      radius: 14,
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: row,
      ),
    );
  }
}
