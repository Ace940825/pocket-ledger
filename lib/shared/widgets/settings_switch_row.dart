import 'package:flutter/material.dart';
import 'package:pocket_ledger/shared/widgets/hairline_card.dart';
import 'package:pocket_ledger/theme/app_colors.dart';
import 'package:pocket_ledger/theme/app_dimens.dart';

/// 设置页「标题 + 副标题 + 开关」行（全应用统一）。
///
/// 取代各页手搭的同构组件：`_SwitchRow` / `_SwitchTile` / `_SettingsSwitchTile`
/// 等。文字样式与颜色全部走 [Theme] / [ColorScheme]，暗色自动适配。
///
/// - [activeThumbColor] 自定义开关激活态拇指色（默认跟随主题）。
/// - [showCrown] 开关左侧显示皇冠小标（付费 / PRO 特性提示）。
/// - [card] 为 `true` 时整行包一层 [HairlineCard]（每卡独立、下间距 12、
///   radius 14），用于需要「卡片化」排版的设置分组；默认 `false`（裸行，
///   由外层容器控制间距）。
/// - [padding] 行内边距，默认仅纵向 [AppDimens.sm]（裸行通常已处于
///   带横向内边距的容器内）；卡片模式建议传 `horizontal: 14, vertical: 4`。
class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.activeThumbColor,
    this.showCrown = false,
    this.card = false,
    this.padding = const EdgeInsets.symmetric(
      vertical: AppDimens.sm,
    ),
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? activeThumbColor;
  final bool showCrown;
  final bool card;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Widget row = Padding(
      padding: padding,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (showCrown) ...<Widget>[
            const Icon(
              Icons.workspace_premium,
              size: 18,
              color: AppPalette.warn,
            ),
            const SizedBox(width: AppDimens.xs),
          ],
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: activeThumbColor,
          ),
        ],
      ),
    );
    if (!card) return row;
    return HairlineCard(
      margin: const EdgeInsets.only(bottom: 12),
      radius: 14,
      padding: EdgeInsets.zero,
      child: row,
    );
  }
}
