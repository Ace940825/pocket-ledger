import 'package:flutter/material.dart';

import 'package:pocket_ledger/core/theme/forest_design_tokens.dart';

/// 弹层内分组小标题（与 ActionGroup 配套，全应用统一）：左对齐大写小字，
/// [danger]=true 时转警示红，用于「数据 / 危险操作」等分组提示。
/// 取代各页私有的 `_SectionLabel`。颜色走 ColorScheme 暗色自动适配。
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {this.danger = false, super.key});

  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 13, 2, 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.16,
          color: danger
              ? ForestSemantic.expense
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 操作行分组容器（全应用统一）：radius 18 圆角 + 发丝线描边 +
/// raised（亮）/ surface（暗）底色。
///
/// 与 [ActionRow] 配套使用（ActionRow 自带顶部发丝线分隔），
/// 取代各页私有的 `_ActionGroup` / 手写圆角描边容器。
/// 颜色走 ColorScheme 暗色自动适配。
class ActionGroup extends StatelessWidget {
  const ActionGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : ForestSurface.raised,
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(children: children),
    );
  }
}

/// 弹层菜单项（与 ActionGroup/ActionRow/SectionLabel 同族，全应用统一）。
///
/// 用于底部弹层的单行菜单项，整行可点击。通过 [isDark] 适配容器底色：
/// - true：深色容器（如标签管理页类别菜单的 sage900 背景）→ 文字用浅色；
/// - false：浅色容器（奶油/卡面）→ 文字用深墨。
/// [danger]=true 时文字转警示红（[ForestSemantic.expense]，对齐 ActionRow
/// 危险语义）。取代标签页私有的 `_MenuItem`。
class MenuItem extends StatelessWidget {
  const MenuItem({
    required this.label,
    required this.onTap,
    this.danger = false,
    this.isDark = false,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final bool danger;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final Color textColor = danger
        ? ForestSemantic.expense
        : (isDark ? ForestSurface.raised : ForestNeutral.textPrimary);
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        child: Text(
          label,
          style: TextStyle(fontSize: 14.5, color: textColor),
        ),
      ),
    );
  }
}
