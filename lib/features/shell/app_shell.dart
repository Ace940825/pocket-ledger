import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/modal_sheet_registry.dart';

/// 底部 4 Tab 外壳。
///
/// 使用 [StatefulShellRoute.indexedStack] 的好处：
/// 切换 Tab 时各分支保持自己的导航栈、滚动位置与页面状态，
/// 从详情页返回后列表不会重新加载、不会跳回顶部。
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  /// 顺序必须与 app_router.dart 里 branches 一一对应。
  static const List<({IconData icon, String label})> _tabs =
      <({IconData icon, String label})>[
    (icon: Icons.home_outlined, label: '首页'),
    (icon: Icons.receipt_long_outlined, label: '账单'),
    (icon: Icons.person_outline, label: '我的'),
    (icon: Icons.insights_outlined, label: '报表'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (int index) {
          // 明细/报销详情等弹层挂在分支导航器上、Tab 栏保持可点；
          // 切 Tab（含回根）时先收起打开中的弹层，落到目标页后
          // 各页数据走 Drift 流自动刷新。
          ModalSheetRegistry.closeAll();
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
