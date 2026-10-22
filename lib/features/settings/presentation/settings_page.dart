import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:pocket_ledger/theme/app_dimens.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/menu_item.dart';
import 'sync_config_card.dart';

/// 设置页。
///
/// 2026-10-21 收口：旧的「云备份与同步」状态卡已删除——其全部功能
/// （模式/上次同步/待同步状态概览 + 立即同步 + 同步历史）迁入
/// [Routes.syncControl] 同步控制页；设置页只保留：
/// · [SyncConfigCard]：云端凭据（端点/令牌）唯一录入处，必须保留；
/// · 「同步控制」菜单入口：同步的中枢操作台。
///
/// 2026-10-22：按用户要求移除「全部功能 / 预算」两个入口（宫格入口收敛）。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(AppDimens.lg),
        children: <Widget>[
          const SyncConfigCard(),
          const SizedBox(height: AppDimens.lg),
          MenuGroup(
            children: <Widget>[
              MenuItem(
                icon: Icons.sync,
                title: '同步控制',
                subtitle: '状态 · 模式 · 方向 · 范围 · 历史撤回',
                onTap: () => context.push(Routes.syncControl),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.lg),
          MenuGroup(
            children: <Widget>[
              MenuItem(
                icon: Icons.info_outline,
                title: '关于',
                subtitle: '本地优先架构 · 数据存在你的设备上',
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
            ],
          ),
        ],
      ),
    );
  }
}
