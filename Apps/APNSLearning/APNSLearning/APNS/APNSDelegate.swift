//
//  APNSDelegate.swift
//  APNSLearning
//
//  Created by Ashish Awasthi on 13/09/26.
//

import UIKit
import UserNotifications

class APNSDelegate: NSObject, UNUserNotificationCenterDelegate, UIApplicationDelegate {
    var messageRepository: MessageRepository?
    static let apnsTokenDidChange = NSNotification.Name("APNSTokenDidChange")
    private let logStore = APNSLogStore.shared
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        application.applicationIconBadgeNumber = 0
        log("🧹 Badge count reset on launch")
        APNSLogStore.shared.add("Application launched")
        return true
    }
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        log("🎯 APNS Device Token: \(token)")
        
        UserDefaults.standard.set(token, forKey: "apnsDeviceToken")
        NotificationCenter.default.post(name: Self.apnsTokenDidChange, object: token)
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        log("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        log("✅ Notification received (foreground): \(userInfo)")
        incrementBadgeCount()
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        log("✅ Notification tapped: \(userInfo)")
        completionHandler()
    }
    
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        log("✅ Silent notification received (background): \(userInfo)")
        incrementBadgeCount()
        Task {
            await storeNotificationIfNeeded(payload: userInfo)
            completionHandler(.newData)
        }
    }
    
    private func storeNotificationIfNeeded(payload: [AnyHashable: Any]) async {
        do {
            try await messageRepository?.storeNotificationIfNeeded(payload: payload)
            log("✓ Message stored in CoreData")
        } catch {
            log("❌ Error storing notification: \(error.localizedDescription)")
        }
    }

    private func incrementBadgeCount() {
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber += 1
            self.log("🔢 Badge count: \(UIApplication.shared.applicationIconBadgeNumber)")
        }
    }

    private func log(_ message: String) {
        print(message)
        Task { @MainActor in
            logStore.add(message)
        }
    }
}
