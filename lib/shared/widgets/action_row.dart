import 'package:flutter/material.dart';

import 'package:pocket_ledger/core/theme/forest_design_tokens.dart';

/// 设置 / 详情页「图标 + 标题 + 副标题 + 箭头」操作行（全应用统一）。
///
/// 取代各页手搭的 `_ActionRow`：左侧 36×36 圆角方底图标（带描边），
/// 右侧自动补 chevron；[danger] 时底色与标题转警示红（删除 / 清理等危险操作）。
/// 颜色走 ColorScheme 暗色自动适配；整行可点（InkWell radius 18，与外层
/// `_ActionGroup` 的圆角容器对齐）。
class ActionRow extends StatelessWidget {
  const ActionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  final Widget icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: scheme.outline),
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: danger
                    ? ForestSemantic.expense.withValues(alpha: 0.10)
                    : (isDark
                        ? ForestGreen.deep.withValues(alpha: 0.16)
                        : ForestGreen.soft),
                border: Border.all(
                  color: danger
                      ? ForestSemantic.expense.withValues(alpha: 0.25)
                      : (isDark
                          ? ForestGreen.deep.withValues(alpha: 0.22)
                          : ForestGreen.softBorder),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: icon,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: danger ? ForestSemantic.expense : scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 16,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
