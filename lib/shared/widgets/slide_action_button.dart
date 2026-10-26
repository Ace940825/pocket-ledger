import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:pocket_ledger/shared/widgets/line_icon_map.dart';
import 'package:pocket_ledger/theme/app_dimens.dart';

/// 左滑操作按钮（圆角药丸 + 轻底色 + 同色图标/文字）。
///
/// 与资产总览/隐藏资产/封存资产等页面的左滑交互统一视觉：
/// 底色取 [color] 的 12% 透明，图标与文字同色，圆角药丸。
class SlideActionButton extends StatelessWidget {
  const SlideActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CustomSlidableAction(
      onPressed: (_) => onPressed(),
      backgroundColor: Colors.transparent,
      foregroundColor: color,
      padding: EdgeInsets.zero,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppDimens.xs / 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            LineGlyph(icon, size: 20, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
