import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../domain/enums.dart';
import '../../../shared/models/money.dart';
import 'bill_io.dart';

/// 截图识别通知 ID（与 iOS 侧 ScreenshotIntent.swift 的 kScreenshotNotificationId 对齐）。
const int kScreenshotNotifId = 1001;

/// 通知 category 标识（iOS 侧注册 action 时用同一字符串）。
const String kScreenshotNotifCategory = 'SCREENSHOT_OCR';

/// action ID：确认入库。
const String kActionConfirm = 'SCREENSHOT_CONFIRM';

/// action ID：取消丢弃。
const String kActionDismiss = 'SCREENSHOT_DISMISS';

/// action ID：查看并修改（拉起 App 到记一笔页）。
const String kActionView = 'SCREENSHOT_VIEW';

/// 暂存的 OCR 识别结果（在通知确认前保持在内存）。
///
/// 由于通知 action 回调可能在 App 被挂起前触发，这里用静态字段暂存
/// 最近一次 OCR 结果；确认时从这里取数据落库，查看时从这里取数据预填表单。
class ScreenshotPendingResult {
  const ScreenshotPendingResult({
    required this.rows,
    required this.screenshotPath,
    this.bookId,
  });

  final List<BillRow> rows;
  final String? screenshotPath;
  final String? bookId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'rows': rows.map((BillRow r) => _rowToJson(r)).toList(),
        'screenshotPath': screenshotPath,
        'bookId': bookId,
      };

  static Map<String, dynamic> _rowToJson(BillRow r) => <String, dynamic>{
        'occurredAt': r.occurredAt.toIso8601String(),
        'type': r.type.name,
        'amountMinor': r.amountMinor,
        'accountName': r.accountName,
        'toAccountName': r.toAccountName,
        'categoryName': r.categoryName,
        'note': r.note,
        'currency': r.currency,
      };
}

/// 最近一次 OCR 暂存结果（静态，通知 action 回调读取）。
ScreenshotPendingResult? pendingResult;

/// 截图识别系统通知服务。
///
/// 负责：
/// 1. 注册通知 category + action 按钮（iOS UNNotificationCategory）
/// 2. OCR 完成后发结果通知（账单摘要 + 确认/取消/查看）
/// 3. 通知 action 回调分发
class ScreenshotNotificationService {
  ScreenshotNotificationService._();

  static final ScreenshotNotificationService instance =
      ScreenshotNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// 初始化通知渠道与 action 注册。
  Future<void> init() async {
    if (_initialized) return;
    const DarwinInitializationSettings ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const AndroidInitializationSettings android =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings = InitializationSettings(
      iOS: ios,
      android: android,
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onResponse,
    );

    // iOS：注册通知 category + action 按钮。
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    // Android：注册通知渠道。
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'screenshot_ocr',
            '账单识别',
            description: '快捷指令截图识别账单的进度与结果通知',
            importance: Importance.high,
          ),
        );

    _initialized = true;
  }

  /// 取冷启动时的通知（App 被通知点击拉起时的 action / payload）。
  Future<NotificationAppLaunchDetails?> getLaunchDetails() =>
      _plugin.getNotificationAppLaunchDetails();

  /// OCR 完成：发结果通知（账单摘要 + 确认/取消/查看）。
  Future<void> showResult({
    required List<BillRow> rows,
    String? screenshotPath,
    String? bookId,
  }) async {
    if (rows.isEmpty) return;

    pendingResult = ScreenshotPendingResult(
      rows: rows,
      screenshotPath: screenshotPath,
      bookId: bookId,
    );

    // 构造通知 body：显示首笔摘要 + 总笔数。
    final BillRow first = rows.first;
    final String amount = Money.fromMinor(first.amountMinor).format();
    final String sign = switch (first.type) {
      TxnType.income => '+',
      TxnType.expense => '-',
      _ => '',
    };
    final String category = first.categoryName ??
        (first.note?.trim().isNotEmpty == true
            ? first.note!.trim()
            : '未分类');
    final String body = rows.length == 1
        ? '$category $sign$amount · ${first.accountName}'
        : '$category $sign$amount 等 ${rows.length} 笔账单';

    const NotificationDetails details = NotificationDetails(
      iOS: DarwinNotificationDetails(
        categoryIdentifier: kScreenshotNotifCategory,
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      android: AndroidNotificationDetails(
        'screenshot_ocr',
        '账单识别',
        channelDescription: '快捷指令截图识别账单的进度与结果通知',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await _plugin.show(
      kScreenshotNotifId,
      '识别到 ${rows.length} 笔账单',
      body,
      details,
      payload: jsonEncode(pendingResult!.toJson()),
    );
  }

  /// OCR 失败：发错误通知。
  Future<void> showError(String message) async {
    const NotificationDetails details = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      android: AndroidNotificationDetails(
        'screenshot_ocr',
        '账单识别',
        channelDescription: '快捷指令截图识别账单的进度与结果通知',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _plugin.show(
      kScreenshotNotifId,
      '账单识别失败',
      message,
      details,
    );
  }

  /// 确认入库成功后：更新通知为"已保存"。
  Future<void> showSaved(int count) async {
    const NotificationDetails details = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      android: AndroidNotificationDetails(
        'screenshot_ocr',
        '账单识别',
        channelDescription: '快捷指令截图识别账单的进度与结果通知',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _plugin.show(
      kScreenshotNotifId,
      '已保存 $count 笔账单',
      '已自动记入口袋账本',
      details,
    );
    // 3 秒后自动移除通知。
    await Future<void>.delayed(const Duration(seconds: 3));
    await _plugin.cancel(kScreenshotNotifId);
  }

  /// 取消：移除通知并清理暂存。
  Future<void> dismiss() async {
    pendingResult = null;
    await _plugin.cancel(kScreenshotNotifId);
  }

  /// 仅移除系统通知（不清理 pendingResult）。
  ///
  /// 用于 Swift 后台识别结果被 App 接管后，去掉冗余的系统通知横幅
  /// （App 内横幅 / 定向导航已替代它）。
  Future<void> cancelNotification() async {
    await _plugin.cancel(kScreenshotNotifId);
  }

  /// 通知点击/action 回调。
  void _onResponse(NotificationResponse response) {
    // payload 携带 OCR 结果，供后续 action 处理使用。
    // actionId 为空表示用户直接点了通知主体（等同于"查看"）。
    final String actionId = response.actionId ?? kActionView;
    // 具体 action 处理由上层（ScreenshotInboxController）注册回调完成。
    // 这里只做分发，不直接操作数据库（因为可能在后台线程）。
    ScreenshotNotificationActionHandler.handle(actionId, response.payload);
  }
}

/// 通知 action 分发器（上层注册处理函数）。
class ScreenshotNotificationActionHandler {
  static Future<void> Function(String action, String? payload)? onAction;

  static void handle(String action, String? payload) {
    onAction?.call(action, payload);
  }
}
