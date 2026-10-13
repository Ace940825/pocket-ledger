import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';
import 'bottom_action_bar.dart';
import 'modal_sheet_registry.dart';
import 'sheet_drag_handle.dart';

/// 底部弹层外壳（全应用统一）：圆角顶 + 拖拽条 + 可选标题 + body + 可选操作栏 + 底部安全区。
///
/// 取代各页 `showModalBottomSheet` 里手写的「Container 圆角 + 36×4 把手 + 标题行
/// + padding + SafeArea」样板。调用方只提供标题与内容。
///
/// 视觉与既有弹层一致（顶部 [AppDimens.radiusSheet] 圆角、发丝线标题底、[SheetDragHandle]），
/// 暗色随 [ColorScheme] 自动适配。
class AppModalSheet extends StatelessWidget {
  const AppModalSheet({
    super.key,
    this.title,
    this.titleWidget,
    this.titleTrailing,
    required this.body,
    this.actions,
    this.bodyPadding = const EdgeInsets.symmetric(
      horizontal: AppDimens.md,
      vertical: AppDimens.sm,
    ),
    this.showHandle = true,
    this.constrainHeight = false,
    this.surfaceColor,
    this.useRootNavigator = false,
  });

  /// 纯文本标题；与 [titleWidget] 二选一，[titleWidget] 优先。
  final String? title;

  /// 自定义标题区（如图标 + 名称 + 关闭钮），优先于 [title]。
  final Widget? titleWidget;

  /// 标题右侧附加件（如全选 / 新增）。
  final Widget? titleTrailing;

  /// 弹层主体内容（滚动与否由调用方决定）。
  final Widget body;

  /// 底部操作栏按钮；非空时用 [BottomActionBar] 包裹。
  final List<Widget>? actions;

  final EdgeInsetsGeometry bodyPadding;
  final bool showHandle;

  /// true 时 body 用 [Expanded] 填满剩余空间（全高弹层，如「列表贴底 + 操作栏
  /// 沉底」）；false（默认）时弹层按内容高度自适应——与 isScrollControlled 解耦。
  final bool constrainHeight;

  final Color? surfaceColor;

  /// 透传 [showModalBottomSheet.useRootNavigator]：true 时弹窗压在根
  /// Navigator（如分期选负债账户需让「添加账户」覆盖底栏导航）。
  final bool useRootNavigator;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final List<Widget> children = <Widget>[
      if (showHandle) const SheetDragHandle(),
      if (titleWidget != null || title != null)
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.md,
            vertical: AppDimens.sm,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: scheme.outline, width: 1),
            ),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: titleWidget ??
                    Text(
                      title!,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
              ),
              if (titleTrailing != null) titleTrailing!,
            ],
          ),
        ),
      if (constrainHeight)
        Expanded(child: Padding(padding: bodyPadding, child: body))
      else
        Padding(padding: bodyPadding, child: body),
    ];

    if (actions != null) {
      children.add(
        BottomActionBar(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: actions!,
          ),
        ),
      );
    }
    children.add(
      const SafeArea(
        top: false,
        bottom: true,
        child: SizedBox.shrink(),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor ?? scheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusSheet),
        ),
      ),
      child: Column(
        mainAxisSize: constrainHeight ? MainAxisSize.max : MainAxisSize.min,
        children: children,
      ),
    );
  }
}

/// 便捷方法：统一调用 [showModalBottomSheet] 并套上 [AppModalSheet]。
///
/// 高度口径（2026-10-13 真机修正）：默认**按内容自适应**——[isScrollControlled]
/// 只影响底层弹层能否突破半屏（键盘弹入 / 长内容必需），不再联动外壳高度；
/// 仅当 [constrainHeight]=true 时 body 才用 [Expanded] 填满剩余空间
/// （适合「列表贴底 + 操作栏沉底」的全高弹层）。
///
/// [useSafeArea] 透传底层路由（默认 false）。[registerWithSheetRegistry]=true
/// 时不走 [showModalBottomSheet]，改为自构 [ModalBottomSheetRoute] 并登记到
/// [ModalSheetRegistry]（切 Tab 时由 AppShell.closeAll() 统一收起）；默认 false
/// 时行为与旧版完全一致，不影响既有弹层。
Future<T?> showAppModalSheet<T>(
  BuildContext context, {
  String? title,
  Widget? titleWidget,
  Widget? titleTrailing,
  required Widget body,
  List<Widget>? actions,
  bool isScrollControlled = false,
  bool showHandle = true,
  bool constrainHeight = false,
  EdgeInsetsGeometry bodyPadding = const EdgeInsets.symmetric(
    horizontal: AppDimens.md,
    vertical: AppDimens.sm,
  ),
  Color? surfaceColor,
  bool useRootNavigator = false,
  bool useSafeArea = false,
  bool registerWithSheetRegistry = false,
}) {
  final AppModalSheet sheet = AppModalSheet(
    title: title,
    titleWidget: titleWidget,
    titleTrailing: titleTrailing,
    body: body,
    actions: actions,
    showHandle: showHandle,
    bodyPadding: bodyPadding,
    constrainHeight: constrainHeight,
    surfaceColor: surfaceColor,
    useRootNavigator: useRootNavigator,
  );

  // 登记到 ModalSheetRegistry：挂 Tab 分支导航器、切 Tab 时由 AppShell.closeAll()
  // 统一收起，避免弹层残留在旧分支。默认 false —— 不影响既有弹层行为。
  if (registerWithSheetRegistry) {
    final ModalBottomSheetRoute<T> route = ModalBottomSheetRoute<T>(
      builder: (_) => sheet,
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
    );
    ModalSheetRegistry.register(route);
    route.popped.whenComplete(() => ModalSheetRegistry.unregister(route));
    return Navigator.of(context, rootNavigator: useRootNavigator).push(route);
  }

  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    useRootNavigator: useRootNavigator,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDimens.radiusSheet),
      ),
    ),
    builder: (_) => sheet,
  );
}
