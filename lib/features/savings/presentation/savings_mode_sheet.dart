import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

import 'savings_modes.dart';

/// 「存钱模式选择」底部弹层（参照小青账）：双列模式卡，点选返回预设。
///
/// 卡片 = 图标 + 模式名 + 一句话玩法说明；点击任意卡片弹出整个面板
/// 并返回对应 [SavingsMode]，点遮罩 / 关闭按钮返回 null（不创建）。
class SavingsModeSheet extends StatelessWidget {
  const SavingsModeSheet({super.key});

  static Future<SavingsMode?> show(BuildContext context) {
    return showModalBottomSheet<SavingsMode>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => const SavingsModeSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // 顶部：关闭按钮 + 居中标题（对标小青账弹层骨架）。
            Row(
              children: <Widget>[
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 22),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '存钱模式选择',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 48), // 与左侧关闭按钮等宽，标题严格居中
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                // 卡片高度 = 图标区 + 标题 + 两行说明。
                childAspectRatio: 0.98,
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 4),
                children: <Widget>[
                  for (final SavingsMode m in SavingsMode.values)
                    SavingsModeCard(
                      mode: m,
                      onTap: () => Navigator.of(context).pop(m),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单张模式卡：图标 + 模式名 + 两行玩法说明。
///
/// 底部弹层与储蓄页「计划」Tab 内嵌九宫格共用；点击行为由调用方注入。
class SavingsModeCard extends StatelessWidget {
  const SavingsModeCard({super.key, required this.mode, required this.onTap});

  final SavingsMode mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.softGreen, // ForestGreen.soft
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(mode.icon, size: 24, color: AppColors.deepGreen),
              ),
              const SizedBox(height: 10),
              Text(
                mode.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                mode.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
