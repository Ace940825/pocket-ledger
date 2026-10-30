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

        // 注册截图识别通知的 category + action 按钮（识别即入账，去掉"确认入库"）。
        // 查看：打开 App 自动落库并跳到账单详情，故加 .foreground；
        // 取消：打开 App 丢弃本次识别结果（含 .destructive 红色样式）。
        let view = UNNotificationAction(
            identifier: "SCREENSHOT_VIEW",
            title: "去查看",
            options: [.foreground]
        )
        let cancel = UNNotificationAction(
            identifier: "SCREENSHOT_DISMISS",
            title: "取消",
            options: [.foreground, .destructive]
        )
        let category = UNNotificationCategory(
            identifier: "SCREENSHOT_OCR",
            actions: [view, cancel],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
