import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../database/app_database.dart';
import '../../../domain/enums.dart';
import '../../../routing/app_router.dart';
import '../../record/presentation/record_sheet.dart';
import '../../record/record_tab.dart';
import '../data/screenshot_inbox.dart';
import '../data/screenshot_notification_service.dart';
import 'screenshot_inbox_banner.dart';
import 'transaction_detail_sheet.dart';

/// 快捷指令截图收件箱引导器：挂在 [MaterialApp] 外层。
///
/// - APP 启动后与每次回前台各触发一次 [ScreenshotInboxController
///   .checkAndProcess]（扫描快捷指令交接文件）；
/// - 监听收件箱状态：进入 parsing / pending / saved / failed 时往根 Overlay 插入
///   顶部通知条，回到 idle 时移除；
/// - 初始化系统通知服务，注册通知 action 回调（确认入库 / 取消 / 查看）；
/// - 「去查看」直接在根导航器上开账单详情弹窗（先收通知条再开弹层，
///   避免手动 Overlay 压住路由弹层）。
class ScreenshotInboxBootstrapper extends ConsumerStatefulWidget {
  const ScreenshotInboxBootstrapper({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ScreenshotInboxBootstrapper> createState() =>
      _ScreenshotInboxBootstrapperState();
}

class _ScreenshotInboxBootstrapperState
    extends ConsumerState<ScreenshotInboxBootstrapper> with WidgetsBindingObserver {
  OverlayEntry? _entry;
  Timer? _pollTimer;
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;

  /// 用户点了通知"查看并修改"，等 App 回前台后跳到记一笔页预填。
  bool _pendingViewFromNotification = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 初始化系统通知服务、注册 action 回调，并捕获冷启动通知（App 被通知
    // 点击拉起时，action / payload 只能在 launch details 里拿到，不会
    // 走 onDidReceiveNotificationResponse）。
    unawaited(_initAndRouteLaunch());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(screenshotInboxProvider.notifier).checkAndProcess();
      }
    });
    // 前台持续轮询：兜底「App 已在前台时，快捷指令写入交接文件却无生命周期
    // 切换事件（resumed 不重复触发）」导致的 checkAndProcess 不被调用竞态。
    // 仅在前台运行；每次只做一次文件存在性检查（withRetry=false），开销可忽略。
    _pollTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (mounted && _lifecycle == AppLifecycleState.resumed) {
        ref
            .read(screenshotInboxProvider.notifier)
            .checkAndProcess(withRetry: false);
      }
    });
  }

  /// 初始化通知服务 + 捕获冷启动通知并路由 action。
  Future<void> _initAndRouteLaunch() async {
    await ScreenshotNotificationService.instance.init();
    ScreenshotNotificationActionHandler.onAction = _onNotificationAction;
    final NotificationAppLaunchDetails? details =
        await ScreenshotNotificationService.instance.getLaunchDetails();
    if (details?.didNotificationLaunchApp == true) {
      final NotificationResponse? resp = details!.notificationResponse;
      // 冷启动通知：直接走同一套 action 路由（confirm/view/dismiss）。
      // actionId 为空（点了通知正文）按 view 处理。
      _onNotificationAction(resp?.actionId ?? kActionView, resp?.payload);
    }
  }

  /// 通知 action 回调：确认入库 / 取消 / 查看。
  void _onNotificationAction(String action, String? payload) {
    final controller = ref.read(screenshotInboxProvider.notifier);
    switch (action) {
      case kActionConfirm:
        unawaited(controller.confirmFromNotification());
      case kActionDismiss:
        unawaited(controller.cancelFromNotification());
      case kActionView:
        // 查看：重建 OCR 结果到内存（Swift 路径从文件重建，Dart 路径已就绪），
        // 标记待跳转，App 回前台后导航到记一笔页。
        unawaited(controller.viewFromNotification());
        _pendingViewFromNotification = true;
      default:
        unawaited(controller.cancelFromNotification());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    if (state == AppLifecycleState.resumed && mounted) {
      // 先处理 pending deep link（通知"查看"跳转），再扫描交接文件。
      if (_pendingViewFromNotification) {
        _pendingViewFromNotification = false;
        _navigateToRecordWithOcr();
      }
      ref.read(screenshotInboxProvider.notifier).checkAndProcess();
    }
  }

  /// 从通知"查看并修改"拉起后，跳到记一笔页预填 OCR 首笔数据。
  void _navigateToRecordWithOcr() {
    final pending = pendingResult;
    if (pending == null || pending.rows.isEmpty) return;
    final row = pending.rows.first;
    final tab = switch (row.type) {
      TxnType.income => RecordTab.income,
      TxnType.expense => RecordTab.expense,
      TxnType.transfer => RecordTab.transfer,
    };
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;
    ctx.push(
      Routes.record,
      extra: RecordSheetLaunchArgs(
        tab,
        null,
        initialAmountMinor: row.amountMinor,
        initialNote: row.note,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ScreenshotInboxState>(screenshotInboxProvider,
        (ScreenshotInboxState? prev, ScreenshotInboxState next) {
      final bool active = next.status != ScreenshotInboxStatus.idle;
      if (active && _entry == null) {
        _entry = OverlayEntry(
          builder: (_) => ScreenshotInboxBanner(
            onDismiss: () =>
                ref.read(screenshotInboxProvider.notifier).dismiss(),
            onOpenDetail: (Transaction txn) {
              // 先收通知条再开弹层：手动 Overlay 会压住路由弹层。
              ref.read(screenshotInboxProvider.notifier).dismiss();
              final BuildContext? rootCtx = rootNavigatorKey.currentContext;
              if (rootCtx != null) {
                TransactionDetailSheet.show(rootCtx, txn);
              }
            },
          ),
        );
        rootNavigatorKey.currentState?.overlay?.insert(_entry!);
      } else if (!active && _entry != null) {
        _removeEntry();
      }
    });
    return widget.child;
  }

  void _removeEntry() {
    _entry?.remove();
    _entry = null;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _entry?.remove();
    _entry = null;
    super.dispose();
  }
}
