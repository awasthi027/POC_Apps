//
//  CBAAuthenticationApp.swift
//  CBAAuthentication
//

import SwiftUI
import UIKit
import UserNotifications

extension Notification.Name {
    static let cbaOpenAppFromLocalNotification = Notification.Name("cbaOpenAppFromLocalNotification")
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            // Token extension cannot prompt for permission; request it in the containing app.
        }
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        print("YubiKeyJob: Notification received.")
        let userInfo = response.notification.request.content.userInfo
        if let marker = userInfo[CBAConstants.keyLocalNotificationOpenApp] as? String,
           marker == CBAConstants.keyLocalNotificationOpenApp {
            print("YubiKeyJob: Forward to Home View")
            NotificationCenter.default.post(name: .cbaOpenAppFromLocalNotification, object: nil)
        }
        completionHandler()
    }
}

@main
struct CBAAuthenticationApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                HomeView()
            }
        }
    }
}
