import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 打开中的底部弹层登记表。
///
/// 流水明细 / 报销账单详情等弹层挂在 Tab 分支导航器上；切换 Tab 时由
/// [AppShell] 调 [closeAll] 统一收起，避免弹层残留在旧分支，落到目标页后
/// 按流数据自动刷新。
///
/// [openCount] 暴露当前打开中的弹层数量（可监听）：AppShell 据此在弹层
/// 打开期间**隐藏底部导航栏**（2026-10-14 反馈：详情弹层打开时底栏不应
/// 露在弹层下方），弹层全部关闭后恢复。
class ModalSheetRegistry {
  ModalSheetRegistry._();

  static final List<Route<void>> _routes = <Route<void>>[];

  /// 当前打开中的登记弹层数量（可监听；AppShell 监听它隐藏/恢复底栏）。
  static final ValueNotifier<int> openCount = ValueNotifier<int>(0);

  static void _notify() => openCount.value = _routes.length;

  static void register(Route<void> route) {
    _routes.add(route);
    _notify();
  }

  static void unregister(Route<void> route) {
    _routes.remove(route);
    _notify();
  }

  /// 收起所有仍打开的登记弹层（切 Tab 时调用）。
  static void closeAll() {
    if (_routes.isEmpty) {
      return;
    }
    for (final Route<void> route in List<Route<void>>.of(_routes)) {
      _routes.remove(route);
      if (route.isActive) {
        route.navigator?.removeRoute(route);
      }
    }
    _notify();
  }
}
