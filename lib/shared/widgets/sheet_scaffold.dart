import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';
import 'bottom_action_bar.dart';
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

  /// true 时 body 用 [Expanded] 填满（配 [showAppModalSheet] 的 isScrollControlled）；
  /// false 时按内容高度自适应。
  final bool constrainHeight;

  final Color? surfaceColor;

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
/// [isScrollControlled]=true 时底层弹层占满高度，[constrainHeight] 同步为 true，
/// body 会被 [Expanded] 填满（适合长列表 / 网格）；否则按内容高度自适应。
Future<T?> showAppModalSheet<T>(BuildContext context, {
  String? title,
  Widget? titleWidget,
  Widget? titleTrailing,
  required Widget body,
  List<Widget>? actions,
  bool isScrollControlled = false,
  bool showHandle = true,
  Color? surfaceColor,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: isScrollControlled,
    useSafeArea: false,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDimens.radiusSheet),
      ),
    ),
    builder: (BuildContext ctx) => AppModalSheet(
      title: title,
      titleWidget: titleWidget,
      titleTrailing: titleTrailing,
      body: body,
      actions: actions,
      showHandle: showHandle,
      constrainHeight: isScrollControlled,
      surfaceColor: surfaceColor,
    ),
  );
}
