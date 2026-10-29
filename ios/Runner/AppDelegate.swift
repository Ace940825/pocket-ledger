import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        // 注册截图识别通知的 category + action 按钮。
        // action：确认入库 / 取消 / 查看并修改。
        // 确认入库：必须打开 App 才能落库（数据库写入在 Dart），故加 .foreground；
        // 保留 .authenticationRequired 让锁屏下需先解锁再确认，避免误触财务操作。
        let confirm = UNNotificationAction(
            identifier: "SCREENSHOT_CONFIRM",
            title: "确认入库",
            options: [.foreground, .authenticationRequired]
        )
        let cancel = UNNotificationAction(
            identifier: "SCREENSHOT_DISMISS",
            title: "取消",
            options: [.destructive]
        )
        let view = UNNotificationAction(
            identifier: "SCREENSHOT_VIEW",
            title: "查看并修改",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: "SCREENSHOT_OCR",
            actions: [confirm, cancel, view],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
