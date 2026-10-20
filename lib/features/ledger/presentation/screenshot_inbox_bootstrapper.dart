import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../routing/app_router.dart';
import '../data/screenshot_inbox.dart';
import 'screenshot_inbox_banner.dart';
import 'transaction_detail_sheet.dart';

/// 快捷指令截图收件箱引导器：挂在 [MaterialApp] 外层。
///
/// - APP 启动后与每次回前台各触发一次 [ScreenshotInboxController
///   .checkAndProcess]（扫描快捷指令交接文件）；
/// - 监听收件箱状态：进入 parsing / saved / failed 时往根 Overlay 插入
///   顶部通知条，回到 idle 时移除；
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(screenshotInboxProvider.notifier).checkAndProcess();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      ref.read(screenshotInboxProvider.notifier).checkAndProcess();
    }
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
    WidgetsBinding.instance.removeObserver(this);
    _entry?.remove();
    _entry = null;
    super.dispose();
  }
}
