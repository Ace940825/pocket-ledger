import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 底部 5 Tab 外壳。
///
/// 使用 [StatefulShellRoute.indexedStack] 的好处：
/// 切换 Tab 时各分支保持自己的导航栈、滚动位置与页面状态，
/// 从详情页返回后列表不会重新加载、不会跳回顶部。
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const List<({IconData icon, String label})> _tabs =
      <({IconData icon, String label})>[
    (icon: Icons.home_outlined, label: '首页'),
    (icon: Icons.receipt_long_outlined, label: '流水'),
    (icon: Icons.account_balance_wallet_outlined, label: '账户'),
    (icon: Icons.pie_chart_outline, label: '预算'),
    (icon: Icons.insights_outlined, label: '报表'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (int index) {
          // 再次点击当前 Tab 时回到该分支的根页面
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: _tabs
            .map(
              (({IconData icon, String label}) tab) => NavigationDestination(
                icon: Icon(tab.icon),
                label: tab.label,
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}
