//
//  APNSManager.swift
//  APNSLearning
//
//  Created by Ashish Awasthi on 13/09/26.
//

import UIKit
import UserNotifications

class APNSManager {
    static let shared = APNSManager()
    
    func requestUserPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                    print("📱 Registered for remote notifications")
                }
            } else {
                print("❌ User denied notification permission")
            }
            return granted
        } catch {
            print("❌ Error requesting notification permission: \(error.localizedDescription)")
            return false
        }
    }
    
    func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
        print("📝 Registering for remote notifications...")
    }
    
    func unregisterFromRemoteNotifications() {
        UIApplication.shared.unregisterForRemoteNotifications()
        print("❌ Unregistered from remote notifications")
    }
    
    func getAPNSToken() -> String? {
        UserDefaults.standard.string(forKey: "apnsDeviceToken")
    }
}

