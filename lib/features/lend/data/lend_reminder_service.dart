import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../database/app_database.dart';
import '../../../domain/enums.dart';

/// 还款本地提醒服务。
///
/// 借还（借入 / 借出）记录带 [LendRecord.dueAt] 且状态为 [LendStatus.ongoing]
/// 时，到期前 [leadDays] 天与到期当天各排程一条本地通知。
///
/// 实现要点：
/// - 本地通知走 UNUserNotificationCenter，**不需要** APNs / 推送证书，
///   免费 Apple 账号（免签分发）即可用。
/// - 到期时间以「UTC epoch 毫秒」存储（与 [LendRepository] 的 [occurredAt]
///   同口径），排程时转成 `tz.TZDateTime` 用 `absoluteTime` 解释——即按绝对
///   时刻触发，落到用户本地时区正好是所设到期日的凌晨，无需再查设备时区。
/// - 每条借还派生两条通知（提前 / 当天），id 由记录 id 的稳定哈希派生，
///   便于整条取消、互不冲突。
class LendReminderService {
  LendReminderService({this.leadDays = 3});

  /// 提前提醒天数（默认 3 天）。后续若要进设置项，从这里提升即可。
  final int leadDays;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// 由借还记录 id 派生通知 id（提前提醒：salt=1；到期当天：salt=2）。
  /// 取 29 位正哈希 ×2 + salt，保证正负都落在 Int32 安全区间、且同记录
  /// 两条通知 id 相差 1 互不覆盖。
  int _idFor(String lendId, int salt) =>
      ((lendId.hashCode & 0x1fffffff) * 2) + salt;

  /// 初始化插件并请求通知权限（iOS 首次启动弹系统授权框；Android 走
  /// 系统通知渠道，13+ 需用户在系统设置里授予 POST_NOTIFICATIONS）。
  Future<void> init() async {
    tz_data.initializeTimeZones();
    const DarwinInitializationSettings ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const AndroidInitializationSettings android =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings =
        InitializationSettings(iOS: ios, android: android);
    await _plugin.initialize(settings);
    // Android 13+ 运行时通知权限（iOS 已由 DarwinInitializationSettings 请求）。
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _ready = true;
  }

  /// 为单条借还记录排程（先取消旧通知，再按需排程提前 / 当天两条）。
  /// [LendRecord.dueAt] 为空或已非进行中（结清 / 核销）时不排程（仅取消）。
  Future<void> scheduleForLend(LendRecord r) async {
    if (!_ready) return;
    await cancelForLend(r.id);
    if (r.dueAt == null || r.status != LendStatus.ongoing) return;

    final tz.TZDateTime due = _toTZ(r.dueAt!);
    final tz.TZDateTime now = tz.TZDateTime.now(tz.UTC);
    const NotificationDetails details = NotificationDetails(
      iOS: DarwinNotificationDetails(),
      android: AndroidNotificationDetails(
        'lend_reminder',
        '还款提醒',
        channelDescription: '借入/借出到期前的还款提醒通知',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    final String dirLabel = r.direction == LendDirection.lendOut ? '借出' : '借入';

    // 提前 leadDays 天（仍属未来才排）。
    final tz.TZDateTime lead = due.subtract(Duration(days: leadDays));
    if (lead.isAfter(now)) {
      await _plugin.zonedSchedule(
        _idFor(r.id, 1),
        '还款提醒',
        '$dirLabel「${r.counterparty}」还有 $leadDays 天到期',
        lead,
        details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }

    // 到期当天。
    if (due.isAfter(now)) {
      await _plugin.zonedSchedule(
        _idFor(r.id, 2),
        '还款到期',
        '$dirLabel「${r.counterparty}」今天到期',
        due,
        details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  /// 取消某条借还记录的两条提醒（结清 / 删除 / 改到期日时调用）。
  Future<void> cancelForLend(String lendId) async {
    if (!_ready) return;
    await _plugin.cancel(_idFor(lendId, 1));
    await _plugin.cancel(_idFor(lendId, 2));
  }

  /// UTC epoch 毫秒 → 以 UTC 为基准的 [tz.TZDateTime]（absoluteTime 解释即按
  /// 该绝对时刻触发，跨时区自然落到本地到期日当天）。
  tz.TZDateTime _toTZ(int dueAtUtcMs) {
    final DateTime dt =
        DateTime.fromMillisecondsSinceEpoch(dueAtUtcMs, isUtc: true);
    return tz.TZDateTime.from(dt, tz.UTC);
  }
}
