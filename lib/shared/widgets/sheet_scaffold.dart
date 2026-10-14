import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';
import 'bottom_action_bar.dart';
import 'modal_sheet_registry.dart';

/// 底部弹层外壳（全应用统一）：悬浮卡（四周留边 + 四角全圆）+ 可选标题 + body
/// + 可选操作栏。
///
/// 取代各页 `showModalBottomSheet` 里手写的「Container 圆角 + 标题行 + padding
/// + SafeArea」样板。调用方只提供标题与内容。
///
/// 拖拽柄已全局移除（2026-10-14 第 19 批反馈：上/下柄都不保留；M3 路由自带的
/// handle 由主题 `showDragHandle: false` 关闭），下滑关闭手势仍然有效。
/// 视觉口径：四角 [AppDimens.radiusSheet] 圆角 + 发丝线标题底，暗色随
/// [ColorScheme] 自动适配。
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

  /// 已废弃（第 19 批起全局移除拖拽柄）：保留参数兼容既有调用点，不再生效。
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
    // 键盘高度避让：弹层内容整体抬到键盘上方（背景延伸到键盘后面，圆角顶仍可见）。
    // 无键盘时为 0，视觉零变化。此前带输入框的弹层（编辑标签/类别等）会被
    // 键盘完全盖住（2026-10-14 真机反馈）。
    final double viewInset = MediaQuery.viewInsetsOf(context).bottom;

    final List<Widget> children = <Widget>[
      // 拖拽柄已全局移除（第 19 批），[showHandle] 参数保留兼容但不再渲染。
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
          // 悬浮卡底部自带 12px 离屏边距，卡内不再做 SafeArea 避让——
          // 否则 home indicator 高度叠加悬浮边距，操作栏下方留白过大
          // （2026-10-14 第 19 批反馈，全弹层统一）。
          useSafeArea: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: actions!,
          ),
        ),
      );
    }
    // 尾部 SafeArea 已删除（第 19 批）：悬浮卡自带离屏边距，卡内无需避让
    // home indicator；键盘高度仍由外层 viewInset padding 负责。

    // 悬浮卡样式（2026-10-14 第 16 批反馈，对标小青账）：四周留边、四角全圆，
    // 弹层像一张卡片浮在遮罩上，而非贴底整宽面板。底层 Material 已透明，
    // 卡片完全由本 Container 自绘 → 全应用所有弹层一处生效。
    return Container(
      // 关键：decoration 不裁剪子级——通宽色块子级（如日历 _sageBar 顶栏、
      // BottomActionBar 底栏）的方形角会伸出卡片圆弧外，在两角形成 3px
      // 方形台阶（2026-10-14 第 17 批反馈「两边还有角」真凶）。
      // antiAlias 把全部子级裁进圆角内。
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.fromLTRB(
        AppDimens.md,
        0,
        AppDimens.md,
        AppDimens.md,
      ),
      decoration: BoxDecoration(
        color: surfaceColor ?? scheme.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusSheet),
        // 悬浮投影：压住留边区透出的背景内容（幽灵角）+ 悬浮层次感。
        boxShadow: AppShadows.floating,
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: viewInset),
        child: Column(
          mainAxisSize: constrainHeight ? MainAxisSize.max : MainAxisSize.min,
          children: children,
        ),
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
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimens.radiusSheet),
    ),
    builder: (_) => sheet,
  );
}
