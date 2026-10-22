import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
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
/// [ColorScheme] 自动适配。四边留边 md；**上边距 = 状态栏高度 + md**——
/// 全高弹层（isScrollControlled + constrainHeight）因此不会顶到状态栏，
/// 贴底短弹层因底层贴底锚定，顶部留边只是不可见空白、视觉零变化。
///
/// **body 槽位高度（2026-10-22 二次修正：ConstrainedBox → Flexible(loose)）**：
/// 早前 body 槽位无高度上限，键盘弹起时 `Padding(bottom: viewInset)` 把卡片
/// 撑到超出屏幕（真机「BOTTOM OVERFLOWED BY 321 PIXELS」）；曾改为
/// `ConstrainedBox(maxHeight: 屏高 − 铬件)`，**但没修掉根因**：
/// `Column(mainAxisSize.min)` 给非 flex 子级的高度约束是 **Infinity**
/// （RenderFlex 对非弹性子级只给内容自然高、不继承父级上限），
/// `ConstrainedBox.additionalConstraints.enforce(Infinity)` 只认自己的上限，
/// **模态路由的 9/16 高度帽（isScrollControlled=false 时
/// `scrollControlDisabledMaxHeightRatio`）被彻底抹掉**——body 实测可拿到
/// 近全屏高，导致：① shrinkWrap 的 ListView 按全内容高度布局、
/// `maxScrollExtent == 0` 完全滑不动，超出卡片的条目被 `Clip.antiAlias`
/// 裁死且不可达（真机「导入问题明细」9 条就裁掉下半截、拖动无反应）；
/// ② 超长内容把 Column 撑爆（RenderFlex overflow）、卡片超出路由帽。
/// 现改为 **`Flexible(fit: loose)`**：body 的上限 = 路由实际帽 − 标题/操作栏/
/// 边距等非弹性同级——由 RenderFlex 按真实剩余空间分配，自动尊重路由帽
/// （9/16 或 isScrollControlled 全屏）与键盘避让；短内容仍取自然高
/// （视觉零变化），超长内容在槽位内滚动、卡片不溢出不裁死。
class AppModalSheet extends StatelessWidget {
  const AppModalSheet({
    super.key,
    this.title,
    this.titleWidget,
    this.titleLeading,
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

  /// 标题左侧附加件（如返回箭头）。
  final Widget? titleLeading;

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

    // 卡片上边距 = 状态栏高度 + md（2026-10-20 用户截图反馈「顶部已经顶到头了」）：
    // 悬浮卡设计规格是「四周留边」（见类文档），但此前上边距恒为 0——
    // 贴底短弹层看不出问题，而 isScrollControlled + constrainHeight 的
    // 全高弹层（分类排序 / 子分类排序 / 记账设置 / 存钱目标计划调整共 4 处）
    // 会一路撑到屏幕顶端，标题直接顶到状态栏。
    // 状态栏高度必须读「原始视图 padding」：弹层路由默认 useSafeArea=false，
    // 底层用 MediaQuery.removePadding(removeTop: true) 包住整个弹层内容
    // （连 viewPadding 一起减掉）；Scaffold 有 AppBar 时也会剥掉页面 body
    // 的 top padding——MediaQuery 在弹层内恒为 0，只有 View.of(context).padding
    // 不受这些剥离影响（真机即状态栏高度）。
    // 底层 _ModalBottomSheetLayout 贴底锚定（offset = 屏高 − 卡高），顶部
    // margin 只是卡片上方的空白：短弹层视觉零变化，长弹层被挡在
    // 「状态栏 + md」处，恢复四边留边口径。
    final double topGap = View.of(context).padding.top + AppDimens.md;

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
              if (titleLeading != null) titleLeading!,
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
      // body 槽位：constrainHeight 时 Expanded 填满剩余空间（全高弹层）；
      // 否则 Flexible(loose) —— 上限 = 路由实际高度帽（9/16 或全屏）减去
      // 标题 / 操作栏 / 边距等非弹性同级后的真实剩余空间。关键点：
      // Column(mainAxisSize.min) 给非 flex 子级的高度约束是 Infinity，
      // 任何「自己猜上限」的 ConstrainedBox 都会把路由的 9/16 帽抹掉
      // （enforce(Infinity) 只认自己的值），导致 body 拿到近全屏高——
      // shrinkWrap 列表 maxScrollExtent=0 滑不动、超出部分被卡片裁死
      // （2026-10-22「导入问题明细」真机反馈）。Flexible 由 RenderFlex
      // 按父级真实约束分配，天然尊重路由帽与键盘避让；短内容取自然高，
      // 视觉与旧版零差异。
      if (constrainHeight)
        Expanded(child: Padding(padding: bodyPadding, child: body))
      else
        Flexible(
          fit: FlexFit.loose,
          child: Padding(padding: bodyPadding, child: body),
        ),
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
      margin: EdgeInsets.fromLTRB(
        AppDimens.md,
        topGap,
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

/// 悬浮卡片式弹层：**点卡片外任意处直接关闭**（[showAppModalSheet] 做不到）。
///
/// 与 [showAppModalSheet] 的关键差别在底层路由：
/// - [showAppModalSheet] 走 `showModalBottomSheet`——它的 sheet 自带一个
///   [Material]，形状是**整块 sheet 矩形**（不是我们的卡片圆角），会把卡片
///   四周的透明留白一起吃掉 → 点框外没反应，只有卡片上方很窄一条才命中
///   遮罩（2026-10-22 真机反馈「分类弹窗点框外没反应」）。
/// - 本函数走 [showGeneralDialog]——整屏路由 + **独立遮罩**：卡片（四边留边
///   的悬浮卡）之外的透明区域落在遮罩上，点击即关闭；遮罩之上是卡片本身，
///   卡片内点击不受影响。
///
/// 视觉与 [showAppModalSheet] 完全一致（都复用 [AppModalSheet] 自绘卡片），
/// 仅路由与遮罩不同。默认 [useRootNavigator] = true（盖在 Tab 分支导航器之上）。
Future<T?> showAppCardModal<T>(
  BuildContext context, {
  String? title,
  Widget? titleWidget,
  Widget? titleLeading,
  Widget? titleTrailing,
  required Widget body,
  List<Widget>? actions,
  EdgeInsetsGeometry bodyPadding = const EdgeInsets.symmetric(
    horizontal: AppDimens.md,
    vertical: AppDimens.sm,
  ),
  Color? surfaceColor,
  bool useRootNavigator = true,
}) {
  final AppModalSheet sheet = AppModalSheet(
    title: title,
    titleWidget: titleWidget,
    titleLeading: titleLeading,
    titleTrailing: titleTrailing,
    body: body,
    actions: actions,
    bodyPadding: bodyPadding,
    surfaceColor: surfaceColor,
    useRootNavigator: useRootNavigator,
  );

  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    // 与 showModalBottomSheet 默认遮罩同值（black54），替换视觉零差异；
    // 走 [AppColors] 令牌以满足「页面不抓原始调色板」的守门规则。
    barrierColor: AppPalette.black54,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (BuildContext ctx, _, __) => Stack(
      children: <Widget>[
        // 卡片贴底、满宽（与底部弹层的观感一致：卡片四周留 md 边距）。
        // MaterialType.transparency 只提供 ink 承载（卡片内的 InkWell 需要
        // Material 祖先），不绘制任何背景——`showGeneralDialog` 不像
        // `showModalBottomSheet` 那样自带 Material。
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Material(
            type: MaterialType.transparency,
            child: sheet,
          ),
        ),
      ],
    ),
    transitionBuilder: (
      BuildContext ctx,
      Animation<double> anim,
      Animation<double> secondary,
      Widget child,
    ) {
      final Animation<double> curved = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
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
