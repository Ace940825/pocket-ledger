import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../shared/widgets/line_icon_map.dart';

/// 筛选页账户行：左侧头像 / 图标盒 + 标题 + 可选副标题 + 右侧圆形勾选圈。
///
/// 抽自账单筛选页的「普通账户行」与「未选择资产（游离账单）」特殊行——
/// 二者结构完全一致，仅 [leading] / [title] / [subtitle] 不同。纯展示，
/// 勾选态与点击由调用方注入。背景沿用原 `AppPalette.white`（暗色适配见全局待办）。
class AccountFilterRow extends StatelessWidget {
  const AccountFilterRow({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    required this.checked,
    required this.onTap,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppPalette.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: <Widget>[
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _CheckCircle(checked: checked),
          ],
        ),
      ),
    );
  }
}

/// 右侧圆形勾选圈：选中=绿底白勾，未选中=灰描边空心圈。
class _CheckCircle extends StatelessWidget {
  const _CheckCircle({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: checked ? AppPalette.ctaGreen : Colors.transparent,
        border: Border.all(
          color: checked ? AppPalette.ctaGreen : cs.onSurfaceVariant,
          width: 1.4,
        ),
      ),
      child: checked
          ? const LineGlyph(Icons.check, size: 14, color: AppPalette.white)
          : null,
    );
  }
}
