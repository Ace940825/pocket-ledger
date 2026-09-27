import 'package:flutter/material.dart';

/// 打开中的底部弹层登记表。
///
/// 流水明细 / 报销账单详情等弹层挂在 Tab 分支导航器上（底部 Tab 栏不被
/// 遮罩盖住、保持可点）；切换 Tab 时由 [AppShell] 调 [closeAll] 统一收起，
/// 避免弹层残留在旧分支，落到目标页后按流数据自动刷新。
class ModalSheetRegistry {
  ModalSheetRegistry._();

  static final List<Route<void>> _routes = <Route<void>>[];

  static void register(Route<void> route) => _routes.add(route);

  static void unregister(Route<void> route) => _routes.remove(route);

  /// 收起所有仍打开的登记弹层（切 Tab 时调用）。
  static void closeAll() {
    for (final Route<void> route in List<Route<void>>.of(_routes)) {
      _routes.remove(route);
      if (route.isActive) {
        route.navigator?.removeRoute(route);
      }
    }
  }
}
