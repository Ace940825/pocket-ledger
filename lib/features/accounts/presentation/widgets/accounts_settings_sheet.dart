import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocket_ledger/providers/asset_stats_settings.dart';
import 'package:pocket_ledger/routing/app_router.dart';
import 'package:pocket_ledger/shared/widgets/menu_item.dart';
import 'package:pocket_ledger/shared/widgets/sheet_scaffold.dart';
import 'package:pocket_ledger/theme/app_dimens.dart';

/// 账户设置弹层（顶部「设置」键触发）。
///
/// 功能入口：
/// - 信用卡管理 / 资产排序 / 隐藏资产列表 / 封存资产列表：点击后返回对应路由，
///   由调用方在弹层关闭后跳转；
/// - 资产统计显示：滑动开关，控制账户页分组卡片是否显示占比百分比，
///   切换即时生效、即时持久化，不返回路由。
class AccountsSettingsSheet extends ConsumerWidget {
  const AccountsSettingsSheet({super.key});

  /// 以底部弹层形式打开（点卡片外任意处可关闭）。
  ///
  /// 返回用户选择的路由；点开关项 / 直接关闭返回 null。
  static Future<String?> show(BuildContext context) {
    return showAppCardModal<String>(
      context,
      title: '账户设置',
      body: const AccountsSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AssetStatsSettings stats = ref.watch(assetStatsSettingsProvider);

    return ListView(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      children: <Widget>[
        MenuItem(
          title: '信用卡管理',
          icon: Icons.credit_card,
          onTap: () => Navigator.of(context).pop(Routes.accountCreditCardRepay),
        ),
        MenuItem(
          title: '资产排序',
          icon: Icons.swap_vert,
          onTap: () => Navigator.of(context).pop(Routes.accountSort),
        ),
        MenuItem(
          title: '隐藏资产列表',
          icon: Icons.visibility_off_outlined,
          onTap: () => Navigator.of(context).pop(Routes.accountHidden),
        ),
        MenuItem(
          title: '封存资产列表',
          icon: Icons.archive_outlined,
          onTap: () => Navigator.of(context).pop(Routes.accountSealed),
        ),
        // 资产统计显示：与上方菜单行结构完全一致（左图标 + 中标题副标题 + 右开关），
        // 不加分隔线，保持视觉统一。
        MenuItem(
          title: '资产统计显示',
          subtitle: '分组模式下，资产显示占比百分比。',
          icon: Icons.bar_chart,
          trailing: Switch(
            value: stats.showGroupPercentage,
            onChanged: (bool v) {
              ref
                  .read(assetStatsSettingsProvider.notifier)
                  .save(stats.copyWith(showGroupPercentage: v));
            },
          ),
        ),
        const SizedBox(height: AppDimens.md),
      ],
    );
  }
}
