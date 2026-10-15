import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';
import '../../theme/app_theme.dart';
import 'hairline_card.dart';
import 'line_icon_map.dart';

/// 菜单行（全应用统一）：左侧 tint 圆底图标 + 标题 + 可选副标题 + 右侧 chevron。
///
/// 取代各页手搭的 `ListTile(leading: Icon, title, trailing: chevron)`；
/// 颜色全部走 ColorScheme 暗色自动适配，触控区 ≥ 44（AA）。
///
/// - [icon] 渲染为 tint 圆底图标；也可用 [leading] 传入任意自定义前置组件
///   （如 ClayIconTile / CategoryGlyph 方块）。
/// - 不传 [trailing] 且可点击时自动补右侧 chevron；底部菜单内不想显示
///   chevron 时传 [trailing] 为 `SizedBox.shrink()`。
class MenuItem extends StatelessWidget {
  const MenuItem({
    super.key,
    required this.title,
    this.leading,
    this.icon,
    this.iconColor,
    this.titleColor,
    this.subtitle,
    this.subtitleColor,

    /// 右侧「当前值」文本（如「简体中文」），显示在 chevron 左侧。
    /// 与 [subtitle]（标题下方次要说明）不同，[value] 用于「标题 …… 值 ›」
    /// 这类「入口 + 当前选中值」的设置行。
    this.value,
    this.trailing,
    this.onTap,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: AppDimens.md,
    ),
  });

  final String title;
  final Widget? leading;
  final IconData? icon;
  final Color? iconColor;
  final Color? titleColor;
  final String? subtitle;
  final Color? subtitleColor;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colors;
    final Color tint = iconColor ?? scheme.primary;
    final Widget leadingW = leading ??
        (icon == null
            ? const SizedBox.shrink()
            : Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppDimens.radiusKey),
                ),
                child: LineGlyph(icon, size: 20, color: tint),
              ));
    final Widget trailingW = trailing ??
        (onTap == null && value == null
            ? const SizedBox.shrink()
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (value != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        value!,
                        style: context.text.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (onTap != null)
                    LineGlyph(
                      Icons.chevron_right,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                ],
              ));
    return ListTile(
      contentPadding: contentPadding,
      minTileHeight: AppDimens.minTouch,
      leading: leadingW,
      title: Text(
        title,
        style: context.text.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
          color: titleColor,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: context.text.bodySmall?.copyWith(
                color: subtitleColor ?? scheme.onSurfaceVariant,
              ),
            ),
      trailing: trailingW,
      onTap: onTap,
    );
  }
}

/// 菜单分组（全应用统一）：包一层 [HairlineCard] 并自动在行间加发丝线。
///
/// 用于设置页 / 账户页等「一组功能入口」；底部菜单内不想嵌套卡片时
/// 传 [card] = false，仅输出带分隔线的列（自行用 Divider 即可）。
class MenuGroup extends StatelessWidget {
  const MenuGroup({
    super.key,
    required this.children,
    this.card = true,
    this.padding,
  });

  final List<Widget> children;
  final bool card;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final List<Widget> stacked = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      if (i > 0) stacked.add(const Divider(height: 1));
      stacked.add(children[i]);
    }
    final Widget column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: stacked,
    );
    if (!card) return column;
    return HairlineCard(
      padding: padding ?? EdgeInsets.zero,
      child: column,
    );
  }
}
