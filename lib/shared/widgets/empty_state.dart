import 'package:flutter/material.dart';

import '../../core/constants/app_dimens.dart';

/// 空状态占位。
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.message,
    super.key,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 56,
              color: theme.colorScheme.outlineVariant,
            ),
            const SizedBox(height: AppDimens.spaceLg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: AppDimens.spaceLg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
