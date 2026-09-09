import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimens.dart';

/// 尚未实现的模块占位页。
///
/// 路由、数据表与同步契约均已就绪，
/// 后续只需在此处填充页面与仓储逻辑，不需要改动架构。
class ModulePlaceholderPage extends StatelessWidget {
  const ModulePlaceholderPage({
    required this.title,
    required this.description,
    super.key,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.construction_outlined,
                size: 56,
                color: theme.colorScheme.outlineVariant,
              ),
              const SizedBox(height: AppDimens.spaceLg),
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppDimens.spaceSm),
              Text(
                description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppDimens.spaceLg),
              Text(
                '数据表与同步契约已就绪，将在下一阶段实现',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
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
