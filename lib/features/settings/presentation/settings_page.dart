import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pocket_ledger/core/theme/forest_design_tokens.dart';
import 'package:pocket_ledger/theme/app_dimens.dart';

import '../../../providers/app_providers.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/confirm_dialog.dart';
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
///
/// 2026-10-25：加「清空全部数据」重置入口（危险区，删除本机所有账目数据、
/// 仅保留账本）。配套修复了「删除导入记录时随导入新建的账户 / 借还 / 投资 /
/// 报销 / 储蓄 / 分期台账及其流水清不干净」——级联删除见
/// [ImportRecordRepository.deleteCascade]。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Color error = context.forest.error;
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
          const SizedBox(height: AppDimens.lg),
          // 危险区：破坏性重置，放最底部并与上文拉开间距。
          MenuGroup(
            children: <Widget>[
              MenuItem(
                icon: Icons.delete_forever_outlined,
                iconColor: error,
                titleColor: error,
                title: '清空全部数据',
                subtitle: '删除本机所有账目数据，仅保留账本（不可恢复）',
                onTap: () => _confirmWipeAll(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 「清空全部数据」二次确认 + 执行。强确认（danger）后调用
  /// [AppDatabase.wipeAllUserData]，删除所有账目表但保留账本。
  Future<void> _confirmWipeAll(BuildContext context, WidgetRef ref) async {
    final bool? ok = await showConfirm(
      context,
      title: '清空全部数据？',
      content: '将删除本机所有账户、账单、借还、报销、储蓄、分期、预算、'
          '投资、分类、标签及导入记录，仅保留账本。此操作不可恢复。\n\n'
          '已配置云端同步的话，云端数据不会被本机删除，但也不会自动拉回覆盖。',
      confirmText: '全部清空',
      danger: true,
    );
    if (ok != true) return;
    try {
      await ref.read(appDatabaseProvider).wipeAllUserData();
      if (context.mounted) showAppToast(context, '已清空全部账目数据');
    } catch (e) {
      if (context.mounted) showAppToast(context, '清空失败：$e');
    }
  }
}
