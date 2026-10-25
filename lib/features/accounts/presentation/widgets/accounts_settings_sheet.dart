import 'package:flutter/material.dart';
import 'package:pocket_ledger/routing/app_router.dart';
import 'package:pocket_ledger/shared/widgets/app_toast.dart';
import 'package:pocket_ledger/shared/widgets/menu_item.dart';
import 'package:pocket_ledger/shared/widgets/sheet_scaffold.dart';
import 'package:pocket_ledger/theme/app_dimens.dart';

/// 账户设置弹层（顶部「设置」键触发）。
///
/// 功能入口：已实现的点击后返回对应路由，由调用方在弹层关闭后跳转；暂未实现的
/// 返回 null 并弹「敬请期待」占位提示。
/// - 信用卡管理：跳转 [Routes.accountCreditCardRepay]（信用卡还款页）；
/// - 资产排序 / 隐藏资产列表 / 封存资产列表 / 资产统计显示：占位，待后续填充。
class AccountsSettingsSheet extends StatelessWidget {
  const AccountsSettingsSheet({super.key});

  /// 以底部弹层形式打开（点卡片外任意处可关闭）。
  ///
  /// 返回用户选择的路由；占位项 / 直接关闭返回 null。
  static Future<String?> show(BuildContext context) {
    return showAppCardModal<String>(
      context,
      title: '账户设置',
      body: const AccountsSettingsSheet(),
    );
  }

  /// 占位点击：提示「敬请期待」后关闭弹层。
  void _placeholder(BuildContext context, String label) {
    showAppToast(context, '$label：敬请期待');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // 五个功能入口。图标走全局线稿（LineGlyph），与账户页其余入口同源。
    // [route] 非空 = 已实现，点击后返回该路由由调用方跳转；为空 = 占位。
    const List<_SettingsItem> items = <_SettingsItem>[
      _SettingsItem(
        '信用卡管理',
        Icons.credit_card,
        route: Routes.accountCreditCardRepay,
      ),
      _SettingsItem('资产排序', Icons.swap_vert),
      _SettingsItem('隐藏资产列表', Icons.visibility_off_outlined),
      _SettingsItem('封存资产列表', Icons.archive_outlined),
      _SettingsItem('资产统计显示', Icons.bar_chart),
    ];

    return ListView(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      children: <Widget>[
        for (final _SettingsItem item in items)
          MenuItem(
            title: item.title,
            icon: item.icon,
            onTap: () {
              if (item.route != null) {
                Navigator.of(context).pop(item.route);
              } else {
                _placeholder(context, item.title);
              }
            },
          ),
        const SizedBox(height: AppDimens.md),
      ],
    );
  }
}

class _SettingsItem {
  const _SettingsItem(this.title, this.icon, {this.route});

  final String title;
  final IconData icon;

  /// 已实现时点击返回的路由；null 表示占位。
  final String? route;
}
