// 口袋账本 · Material 图标 → 线稿映射桥接
// 落点：lib/shared/widgets/line_icon_map.dart
//
// 用途（2026-10-15「把所有图标换成线稿风格」）：
//   全站功能/UI 图标此前散落 Material `Icons.*`（580 处引用 / 220 个不同
//   图标名），与 A3 线稿设计稿的分类/账户线稿风格割裂。本文件提供
//   **单一映射入口**，把任意 Material 图标翻译成 [LineIconKind]，
//   配合 [LineGlyph] 渲染，即可零语义改动地把 `Icon(Icons.x)`
//   换成线稿外观（调用点仅需把 `Icon(` 改成 `LineGlyph(`）。
//
// 设计取舍：
//   - 以 `IconData` 本身作为 Map 键（`IconData` 已重写 `==`/`hashCode`，
//     按 codePoint + fontFamily + matchTextDirection 比较），比手抄
//     codePoint 更稳，也不会因 Material 版本微调而错配。
//   - 兜底：未收录图标 → [LineIconKind.otherDots]，保证永远有线稿
//     外观，绝不回落到 Material（否则会重新割裂）。
//   - 保持「一个 Material 图标族（xxx / xxx_outlined / xxx_rounded）」
//     共用同一条线稿，避免同语义出现两种字形。
library;

import 'package:flutter/material.dart';

import 'line_icons.dart';

/// Material 图标 → 线稿字形映射（唯一事实来源）。
///
/// 语义优先原则：
///   - 有业务线稿的（账户 / 分类 / 资金往来）→ 复用对应 `LineIconKind`
///     而不是新造一个泛化图标，保证与分类区视觉同族。
///   - 纯功能/UI 的（增删改查、导航、状态）→ 新增的「功能 / UI」字形。
final Map<IconData, LineIconKind> materialLineKindMap =
    <IconData, LineIconKind>{
  // ── 关闭 / 取消 / 清除 ──
  Icons.close: LineIconKind.close,
  Icons.cancel: LineIconKind.close,
  Icons.clear: LineIconKind.close,
  Icons.remove_circle_outline: LineIconKind.minus,

  // ── 勾选 ──
  Icons.check: LineIconKind.check,
  Icons.check_circle: LineIconKind.checkCircle,
  Icons.check_circle_outline: LineIconKind.checkCircle,
  Icons.verified: LineIconKind.verified,
  Icons.done: LineIconKind.check,

  // ── 增删改 ──
  Icons.add: LineIconKind.add,
  Icons.add_circle_outline: LineIconKind.add,
  Icons.remove: LineIconKind.minus,
  Icons.edit_outlined: LineIconKind.pencil,
  Icons.edit: LineIconKind.pencil,
  Icons.edit_note: LineIconKind.pencil,
  Icons.edit_note_outlined: LineIconKind.pencil,
  Icons.delete_outline: LineIconKind.deleteOutline,
  Icons.delete_forever: LineIconKind.deleteOutline,
  Icons.drive_file_move_outlined: LineIconKind.archiveBox,
  Icons.archive_outlined: LineIconKind.archiveBox,
  Icons.unarchive_outlined: LineIconKind.archiveBox,

  // ── 导航：箭头 / 折叠 ──
  Icons.arrow_back: LineIconKind.arrowBack,
  Icons.arrow_back_ios_new: LineIconKind.arrowBack,
  Icons.chevron_left: LineIconKind.chevronLeft,
  Icons.chevron_right: LineIconKind.chevronRight,
  Icons.keyboard_arrow_down: LineIconKind.chevronDown,
  Icons.keyboard_arrow_down_rounded: LineIconKind.chevronDown,
  Icons.keyboard_arrow_up: LineIconKind.chevronUp,
  Icons.expand_more: LineIconKind.chevronDown,
  Icons.expand_less: LineIconKind.chevronUp,
  Icons.arrow_drop_down: LineIconKind.chevronDown,
  Icons.arrow_right_alt: LineIconKind.arrowRight,
  Icons.arrow_upward_rounded: LineIconKind.arrowUpRight,
  Icons.arrow_downward_rounded: LineIconKind.arrowDownLeft,
  Icons.subdirectory_arrow_right_outlined: LineIconKind.arrowRight,
  Icons.north_east: LineIconKind.arrowUpRight,
  Icons.north_west: LineIconKind.arrowUpLeft,
  Icons.south_west: LineIconKind.arrowDownLeft,
  Icons.vertical_align_top_outlined: LineIconKind.moveUp,

  // ── 菜单 / 更多 ──
  Icons.menu_rounded: LineIconKind.menuLines,
  Icons.more_horiz: LineIconKind.otherDots,
  Icons.more_horiz_outlined: LineIconKind.otherDots,
  Icons.more_vert: LineIconKind.moreVert,
  Icons.drag_handle: LineIconKind.dragHandle,
  Icons.circle: LineIconKind.circle,
  Icons.circle_outlined: LineIconKind.circle,

  // ── 搜索 / 筛选 / 排序 ──
  Icons.search: LineIconKind.search,
  Icons.preview_outlined: LineIconKind.eye,
  Icons.gps_fixed: LineIconKind.location,
  Icons.backspace_outlined: LineIconKind.backspace,
  Icons.keyboard_hide_outlined: LineIconKind.keyboardHide,
  Icons.inventory_2_outlined: LineIconKind.inventory,
  Icons.tune: LineIconKind.sliders,
  Icons.tune_rounded: LineIconKind.sliders,
  Icons.filter_list: LineIconKind.filterList,
  Icons.filter_alt: LineIconKind.filterAlt,
  Icons.sort_outlined: LineIconKind.sortDesc,
  Icons.sort_rounded: LineIconKind.sortDesc,

  // ── 时间 ──
  Icons.calendar_month_outlined: LineIconKind.calendar,
  Icons.calendar_today_outlined: LineIconKind.calendar,
  Icons.calendar_month: LineIconKind.calendar,
  Icons.schedule: LineIconKind.clock,
  Icons.schedule_rounded: LineIconKind.scheduleClock,
  Icons.access_time_outlined: LineIconKind.clock,
  Icons.history: LineIconKind.repeatArrow,
  Icons.history_outlined: LineIconKind.repeatArrow,
  Icons.hourglass_bottom: LineIconKind.hourglass,
  Icons.timer_outlined: LineIconKind.timer,
  Icons.repeat_outlined: LineIconKind.repeatArrow,
  Icons.replay_outlined: LineIconKind.repeatArrow,
  Icons.autorenew: LineIconKind.sync,
  Icons.timeline: LineIconKind.timeline,

  // ── 账户 / 资金 ──
  Icons.account_balance_wallet_outlined: LineIconKind.wallet,
  Icons.account_balance_outlined: LineIconKind.bank,
  Icons.account_box_outlined: LineIconKind.wallet,
  Icons.account_balance: LineIconKind.bank,
  Icons.savings_outlined: LineIconKind.savings,
  Icons.credit_card: LineIconKind.card,
  Icons.credit_card_outlined: LineIconKind.card,
  Icons.card_membership_outlined: LineIconKind.membership,
  Icons.payments_outlined: LineIconKind.handshakeMoney,
  Icons.payment_outlined: LineIconKind.receipt,
  Icons.paid_outlined: LineIconKind.ticket,
  Icons.redeem_outlined: LineIconKind.loyalty,
  Icons.currency_yuan: LineIconKind.yuan,
  Icons.currency_yuan_outlined: LineIconKind.yuan,
  Icons.percent_outlined: LineIconKind.percent,
  Icons.point_of_sale: LineIconKind.pointOfSale,
  Icons.confirmation_number_outlined: LineIconKind.ticket,
  Icons.balance: LineIconKind.balance,
  Icons.receipt_outlined: LineIconKind.receipt,
  Icons.receipt_long: LineIconKind.receipt,
  Icons.receipt_long_outlined: LineIconKind.receipt,
  Icons.shopping_cart_outlined: LineIconKind.shoppingBag,
  Icons.local_atm_outlined: LineIconKind.wallet,

  // ── 账户/往来语义（有专用线稿，复用而非新造）──
  Icons.handshake_outlined: LineIconKind.handshake,
  Icons.assignment_return_outlined: LineIconKind.handshake,
  Icons.swap_horiz: LineIconKind.swapHorizontal,
  Icons.swap_horiz_outlined: LineIconKind.swapHorizontal,
  Icons.swap_horiz_rounded: LineIconKind.swapHorizontal,
  Icons.swap_vert: LineIconKind.swapVertical,
  Icons.swap_vert_rounded: LineIconKind.swapVertical,
  Icons.import_export: LineIconKind.swapHorizontal,
  Icons.sync: LineIconKind.sync,
  Icons.sync_alt: LineIconKind.sync,
  Icons.cloud_sync_outlined: LineIconKind.sync,
  Icons.refresh: LineIconKind.refresh,
  Icons.refresh_outlined: LineIconKind.refresh,

  // ── 文件 / 云 ──
  Icons.subject_rounded: LineIconKind.docLines,
  Icons.attach_file: LineIconKind.attach,
  Icons.attachment: LineIconKind.attach,
  Icons.save_outlined: LineIconKind.save,
  Icons.content_copy: LineIconKind.copy,
  Icons.copy_outlined: LineIconKind.copy,
  Icons.link: LineIconKind.link,
  Icons.send_outlined: LineIconKind.send,
  Icons.cloud: LineIconKind.cloud,
  Icons.cloud_outlined: LineIconKind.cloud,
  Icons.cloud_upload_outlined: LineIconKind.cloudUp,
  Icons.cloud_download_outlined: LineIconKind.cloudDown,
  Icons.file_upload: LineIconKind.cloudUp,
  Icons.folder_open_outlined: LineIconKind.folderOpen,
  Icons.inbox_outlined: LineIconKind.inbox,
  Icons.bookmark_outline: LineIconKind.bookmark,
  Icons.pin_outlined: LineIconKind.pin,
  Icons.push_pin_outlined: LineIconKind.pin,
  Icons.flag_outlined: LineIconKind.flag,
  Icons.qr_code: LineIconKind.barcode,

  // ── 视图切换 ──
  Icons.grid_view_outlined: LineIconKind.grid,
  Icons.apps: LineIconKind.appsGrid,
  Icons.view_list_rounded: LineIconKind.listView,
  Icons.list_alt_outlined: LineIconKind.listView,
  Icons.category_outlined: LineIconKind.grid,

  // ── 设置 / 隐私 ──
  Icons.settings_outlined: LineIconKind.settings,
  Icons.settings: LineIconKind.settings,
  Icons.lock_outline: LineIconKind.lock,
  Icons.key_outlined: LineIconKind.key,
  Icons.vpn_key_outlined: LineIconKind.key,
  Icons.visibility_outlined: LineIconKind.eye,
  Icons.visibility_off_outlined: LineIconKind.eyeOff,
  Icons.privacy_tip_outlined: LineIconKind.permission,
  Icons.shield_outlined: LineIconKind.permission,
  Icons.admin_panel_settings_outlined: LineIconKind.permission,

  // ── 状态 / 反馈 ──
  Icons.info_outline: LineIconKind.info,
  Icons.error_outline: LineIconKind.error,
  Icons.help_outline: LineIconKind.help,
  Icons.help_outline_rounded: LineIconKind.help,
  Icons.warning_amber_rounded: LineIconKind.warning,
  Icons.dangerous_outlined: LineIconKind.warning,
  Icons.block: LineIconKind.warning,
  Icons.contrast_rounded: LineIconKind.contrast,

  // ── 图表 / 统计 ──
  Icons.trending_up: LineIconKind.trendUp,
  Icons.trending_up_outlined: LineIconKind.trendUp,
  Icons.trending_up_rounded: LineIconKind.trendUp,
  Icons.trending_down_outlined: LineIconKind.trendDown,
  Icons.show_chart: LineIconKind.chartLine,
  Icons.show_chart_outlined: LineIconKind.chartLine,
  Icons.pie_chart_outline: LineIconKind.chartPie,
  Icons.donut_small_outlined: LineIconKind.chartPie,
  Icons.donut_large_outlined: LineIconKind.chartPie,
  Icons.candlestick_chart_outlined: LineIconKind.chartCandle,
  Icons.sports_bar_outlined: LineIconKind.chartBar,
  Icons.auto_graph: LineIconKind.dashboard,
  Icons.leaderboard: LineIconKind.leaderboard,

  // ── 分类语义（复用分类线稿，保持同族）──
  Icons.restaurant_outlined: LineIconKind.food,
  Icons.rice_bowl_outlined: LineIconKind.food,
  Icons.emoji_food_beverage_outlined: LineIconKind.food,
  Icons.local_cafe_outlined: LineIconKind.coffee,
  Icons.coffee_outlined: LineIconKind.coffee,
  Icons.cake_outlined: LineIconKind.cake,
  Icons.icecream_outlined: LineIconKind.cake,
  Icons.cookie_outlined: LineIconKind.cake,
  Icons.lunch_dining_outlined: LineIconKind.lunch,
  Icons.breakfast_dining_outlined: LineIconKind.breakfast,
  Icons.dinner_dining_outlined: LineIconKind.dinner,
  Icons.tapas_outlined: LineIconKind.skewer,
  Icons.local_drink_outlined: LineIconKind.beverage,
  Icons.liquor_outlined: LineIconKind.tobacco,
  Icons.shopping_bag_outlined: LineIconKind.shoppingBag,
  Icons.checkroom_outlined: LineIconKind.clothing,
  Icons.content_cut_outlined: LineIconKind.personalCare,
  Icons.cleaning_services_outlined: LineIconKind.hygiene,
  Icons.handyman_outlined: LineIconKind.handyman,
  Icons.chair_outlined: LineIconKind.chair,
  Icons.favorite_outline: LineIconKind.heart,
  Icons.card_giftcard_outlined: LineIconKind.giftRibbon,
  Icons.music_note_outlined: LineIconKind.musicNote,
  Icons.movie_outlined: LineIconKind.digitalFun,
  Icons.sports_esports_outlined: LineIconKind.games,
  Icons.sports_outlined: LineIconKind.fitness,
  Icons.fitness_center_outlined: LineIconKind.fitness,
  Icons.spa_outlined: LineIconKind.spa,
  Icons.directions_car_outlined: LineIconKind.carCare,
  Icons.directions_bus_outlined: LineIconKind.transit,
  Icons.train_outlined: LineIconKind.transit,
  Icons.local_taxi_outlined: LineIconKind.taxiRental,
  Icons.two_wheeler_outlined: LineIconKind.rider,
  Icons.local_gas_station_outlined: LineIconKind.fuel,
  Icons.flight_outlined: LineIconKind.flight,
  Icons.flight_takeoff_outlined: LineIconKind.flight,
  Icons.hotel_outlined: LineIconKind.lodging,
  Icons.beach_access_outlined: LineIconKind.travelVacation,
  Icons.local_shipping_outlined: LineIconKind.shipping,
  Icons.store_outlined: LineIconKind.store,
  Icons.storefront_outlined: LineIconKind.store,
  Icons.local_convenience_store_outlined: LineIconKind.store,
  Icons.business_center_outlined: LineIconKind.briefcase,
  Icons.work_outline: LineIconKind.briefcase,
  Icons.school_outlined: LineIconKind.openBook,
  Icons.menu_book_outlined: LineIconKind.menuBook,
  Icons.auto_stories_outlined: LineIconKind.openBook,
  Icons.book: LineIconKind.openBook,
  Icons.menu_book: LineIconKind.menuBook,
  Icons.local_hospital_outlined: LineIconKind.medicalCross,
  Icons.medical_services_outlined: LineIconKind.medicalBag,
  Icons.vaccines_outlined: LineIconKind.checkup,
  Icons.pets_outlined: LineIconKind.petFood,
  Icons.toys_outlined: LineIconKind.hobby,
  Icons.label_outline: LineIconKind.tag,
  Icons.label_outlined: LineIconKind.tag,
  Icons.smartphone_outlined: LineIconKind.smartphone,
  Icons.devices_outlined: LineIconKind.devices,
  Icons.computer_outlined: LineIconKind.devices,
  Icons.laptop_outlined: LineIconKind.devices,
  Icons.wifi_outlined: LineIconKind.telecom,
  Icons.videocam_outlined: LineIconKind.video,
  Icons.camera_alt_outlined: LineIconKind.camera,
  Icons.photo_library_outlined: LineIconKind.photo,
  Icons.image_outlined: LineIconKind.photo,
  Icons.collections_outlined: LineIconKind.photo,
  Icons.broken_image_outlined: LineIconKind.brokenImage,
  Icons.brush_outlined: LineIconKind.paintBrush,
  Icons.eco_outlined: LineIconKind.eco,
  Icons.umbrella_outlined: LineIconKind.umbrella,
  Icons.volunteer_activism_outlined: LineIconKind.donation,
  Icons.apple_outlined: LineIconKind.apple,
  Icons.diamond_outlined: LineIconKind.gem,
  Icons.badge_outlined: LineIconKind.badge,
  Icons.emoji_events_outlined: LineIconKind.bonusTrophy,
  Icons.stars_rounded: LineIconKind.sparkles,
  Icons.auto_awesome: LineIconKind.autoAwesome,
  Icons.auto_fix_high_outlined: LineIconKind.cameraAuto,
  Icons.calculate_outlined: LineIconKind.calculator,
  Icons.drag_indicator: LineIconKind.dragHandle,
  Icons.stadium_outlined: LineIconKind.stadium,
  Icons.child_care_outlined: LineIconKind.childCare,
  Icons.face_outlined: LineIconKind.child,
  Icons.masks_outlined: LineIconKind.face,
  Icons.beach_access: LineIconKind.beach,
  Icons.pool_outlined: LineIconKind.swimming,
  Icons.hiking_outlined: LineIconKind.hiking,
  Icons.emoji_nature_outlined: LineIconKind.eco,
  Icons.translate: LineIconKind.translateLang,
  Icons.g_translate_outlined: LineIconKind.translateLang,
  Icons.alt_route_outlined: LineIconKind.altRoute,
  Icons.memory_outlined: LineIconKind.memory,
  Icons.text_fields: LineIconKind.textFields,
  Icons.monitor_outlined: LineIconKind.monitor,
  Icons.devices_other_outlined: LineIconKind.devices,
  Icons.android_outlined: LineIconKind.android,
  Icons.phone_android_outlined: LineIconKind.android,
  Icons.phonelink_setup_outlined: LineIconKind.vpn,
  Icons.cloud_off_outlined: LineIconKind.offline,
  Icons.remove_road_outlined: LineIconKind.horizontalRule,
};

/// 取 Material 图标对应的线稿字形；未收录时兜底为 [LineIconKind.otherDots]。
///
/// 兜底刻意**不回落 Material**，以保证「全站无线稿外图标」这一不变量。
LineIconKind materialLineKind(IconData icon) =>
    materialLineKindMap[icon] ?? LineIconKind.otherDots;

/// 兼容 [Icon] 调用签名的线稿图标。
///
/// 用途：把 `Icon(Icons.foo, size: 20, color: tint)` 机械替换为
/// `LineGlyph(Icons.foo, size: 20, color: tint)`，外观即变为线稿，
/// 调用点其余语义（尺寸 / 颜色 / 无障碍标签）保持不变。
class LineGlyph extends StatelessWidget {
  const LineGlyph(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  });

  final IconData icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final Widget glyph = LineIcon(
      materialLineKind(icon),
      size: size ?? IconTheme.of(context).size ?? 16,
      color: color,
    );
    final String? label = semanticLabel;
    if (label == null || label.isEmpty) return glyph;
    return Semantics(label: label, child: glyph);
  }
}

/// Material 图标 → 线稿字形的直接转换（供自定义 widget 内部渲染用）。
///
/// 用于那些把图标作为 `final IconData icon` 字段向下传递的组件——
/// 字段类型保持 `IconData` 不变（调用点零改动），只在渲染处走线稿。
Widget lineGlyphOf(
  IconData icon, {
  double? size,
  Color? color,
  String? semanticLabel,
}) =>
    LineGlyph(icon, size: size, color: color, semanticLabel: semanticLabel);
