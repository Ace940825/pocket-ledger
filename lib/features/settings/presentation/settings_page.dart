import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../providers/app_providers.dart';
import '../../../routing/app_router.dart';
import '../../../sync/sync_engine.dart';
import 'sync_config_card.dart';

/// 同步状态卡片：展示适配器、上次同步时间、待同步条数，并提供手动同步。
class SyncStatusCard extends ConsumerWidget {
  const SyncStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SyncState> state = ref.watch(syncControllerProvider);
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.cloud_sync_outlined),
                const SizedBox(width: AppDimens.spaceSm),
                Text('云备份与同步', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: AppDimens.spaceMd),
            state.when(
              data: (SyncState s) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _InfoRow(label: '模式', value: s.adapterName),
                  _InfoRow(
                    label: '上次同步',
                    value: s.lastSyncedAt == null || s.lastSyncedAt == 0
                        ? '从未同步'
                        : DateTime.fromMillisecondsSinceEpoch(
                            s.lastSyncedAt!,
                          ).toLocal().toString().substring(0, 19),
                  ),
                  _InfoRow(label: '待同步', value: '${s.pendingCount} 条'),
                  if (s.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppDimens.spaceSm),
                      child: Text(
                        s.error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                ],
              ),
              loading: () => const LinearProgressIndicator(),
              error: (Object e, StackTrace? s) => Text('状态加载失败：$e'),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            // 未配置端点/令牌时按钮置灰，避免用户点了却什么都没发生
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: state.value?.status == SyncStatus.disabled
                    ? null
                    : () => ref.read(syncControllerProvider.notifier).syncNow(),
                icon: const Icon(Icons.sync),
                label: const Text('立即同步'),
              ),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              '云端仅用于多设备备份与共享。关闭后应用依然是功能完整的本地记账工具。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(value),
        ],
      ),
    );
  }
}

/// 设置页
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        children: <Widget>[
          const SyncConfigCard(),
          const SizedBox(height: AppDimens.spaceLg),
          const SyncStatusCard(),
          const SizedBox(height: AppDimens.spaceLg),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.grid_view_outlined),
                  title: const Text('全部功能'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(Routes.more),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.pie_chart_outline),
                  title: const Text('预算'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(Routes.budget),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.spaceLg),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('关于'),
              subtitle: const Text('本地优先架构 · 数据存在你的设备上'),
              onTap: () => showAboutDialog(
                context: context,
                applicationName: '口袋账本',
                applicationVersion: '1.0.0',
                children: const <Widget>[
                  Text('本地数据库：SQLite（SQLCipher 加密）'),
                  Text('云端同步：Cloudflare D1（可选，永久免费额度）'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
