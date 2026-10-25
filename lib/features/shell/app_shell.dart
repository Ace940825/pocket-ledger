import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/line_icons.dart';
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
  static const List<({LineIconKind icon, String label})> _tabs =
      <({LineIconKind icon, String label})>[
    (icon: LineIconKind.house, label: '首页'),
    (icon: LineIconKind.book, label: '账单'),
    (icon: LineIconKind.person, label: '我的'),
    (icon: LineIconKind.trendUp, label: '报表'),
  ];

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: navigationShell,
      // 登记弹层（流水/报销详情等）打开期间隐藏底栏（2026-10-14 反馈：
      // 弹层打开时底部导航栏不应露在弹层下方），全部关闭后恢复。
      bottomNavigationBar: ValueListenableBuilder<int>(
        valueListenable: ModalSheetRegistry.openCount,
        builder: (BuildContext context, int openCount, Widget? _) =>
            AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: openCount > 0
              ? const SizedBox.shrink(key: ValueKey<String>('nav-hidden'))
              : MediaQuery.removePadding(
                  context: context,
                  removeBottom: true,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: NavigationBar(
                      key: const ValueKey<String>('nav-bar'),
                      selectedIndex: navigationShell.currentIndex,
                      onDestinationSelected: (int index) {
                        // 明细/报销详情等弹层挂在分支导航器上；切 Tab（含回根）
                        // 时先收起打开中的弹层，落到目标页后各页数据走 Drift 流
                        // 自动刷新。
                        ModalSheetRegistry.closeAll();
                        // 再次点击当前 Tab 时回到该分支的根页面
                        navigationShell.goBranch(
                          index,
                          initialLocation:
                              index == navigationShell.currentIndex,
                        );
                      },
                      destinations: _tabs
                          .asMap()
                          .entries
                          .map(
                            (
                              MapEntry<int, ({LineIconKind icon, String label})>
                                  entry,
                            ) =>
                                NavigationDestination(
                              icon: LineIcon(
                                entry.value.icon,
                                size: 24,
                                color: entry.key == navigationShell.currentIndex
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant,
                              ),
                              label: entry.value.label,
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
