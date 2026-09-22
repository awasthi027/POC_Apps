//
//  APNSDelegate.swift
//  BGTaskLearning
//
//  Created by Ashish Awasthi on 22/09/26.
//

import UIKit
import UserNotifications
import SwiftData
import Foundation

class APNSDelegate: NSObject, UNUserNotificationCenterDelegate, UIApplicationDelegate {
    static let apnsTokenDidChange = NSNotification.Name("APNSTokenDidChange")
    private let logStore = APNSLogStore.shared
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Set APNS delegate
        UNUserNotificationCenter.current().delegate = self
  
        log("🧹 Badge count reset on launch")
        logStore.add("Application launched")
        
        return true
    }
    
    // MARK: - Device Token Registration
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        log("🎯 APNS Device Token: \(token)")
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        log("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    // MARK: - Notification Handlers
    
    /// Called when notification arrives while app is in foreground
    /// - Regular push notifications (without content-available: 1)
    /// - User can see the app
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        log("✅ Notification received (foreground): \(userInfo)")
        
        // Handle foreground notification business logic
        handleForegroundNotification(userInfo: userInfo)
     
        // Display notification to user
        completionHandler([.banner, .sound, .badge])
    }
    
    /// Called when user taps on a notification
    /// - Works in any app state (foreground, background, quit)
    /// - Only called when user actively taps
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        log("✅ Notification tapped by user: \(userInfo)")
        
        // Handle notification tap business logic
        handleNotificationTap(userInfo: userInfo, action: response.actionIdentifier)
        
        completionHandler()
    }
    
    /// Called for silent push notifications (content-available: 1)
    /// - Works in ANY app state: quit, background, or foreground
    /// - REQUIRES Background Modes enabled in Info.plist
    /// - Gets ~30 seconds to process
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        log("✅ Silent notification received (background): \(userInfo)")
        
        // Handle silent background notification business logic
        Task {
            await handleSilentNotification(userInfo: userInfo)
            completionHandler(.newData)
        }
    }
    
    // MARK: - Business Logic Handlers
    
    /// Handle notification received in foreground
    private func handleForegroundNotification(userInfo: [AnyHashable: Any]) {
        // Extract notification data
        if let aps = userInfo["aps"] as? [String: Any] {
            if let alert = aps["alert"] as? [String: Any] {
                let title = alert["title"] as? String ?? "Notification"
                let body = alert["body"] as? String ?? ""
                log("📌 Alert: \(title) - \(body)")
            }
        }
        // Test download from foreground notification
        startTestDownload(with: SwiftDataManager.shared.dataStore)
    }
    
    /// Handle notification tap
    private func handleNotificationTap(userInfo: [AnyHashable: Any], action: String) {
        log("🎯 User tapped notification with action: \(action)")
      
    }
    
    /// Handle silent push notification in background
    private func handleSilentNotification(userInfo: [AnyHashable: Any]) async {
        log("⚙️ Processing silent notification in background")
        log("📥 Starting download from APNS...")
        await startDownloadFromAPNS(payload: userInfo)
        // Test download from foreground notification
       // startTestDownload(with: SwiftDataManager.shared.dataStore)
        
    }
    
    
    // MARK: - Background Operations
    
    private func syncDownloads(payload: [AnyHashable: Any]) async {
        // Simulate download sync
        do {
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            log("✅ Downloads synced successfully")
        } catch {
            log("❌ Download sync failed: \(error.localizedDescription)")
        }
    }
    
    private func syncTasks(payload: [AnyHashable: Any]) async {
        // Simulate task sync
        do {
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            log("✅ Tasks synced successfully")
        } catch {
            log("❌ Task sync failed: \(error.localizedDescription)")
        }
    }
    
    private func refreshAppData(payload: [AnyHashable: Any]) async {
        // Simulate data refresh
        do {
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            log("✅ App data refreshed")
        } catch {
            log("❌ Data refresh failed: \(error.localizedDescription)")
        }
    }
    
    private func checkStatus(payload: [AnyHashable: Any]) async {
        // Simulate status check
        do {
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            if let status = payload["status"] as? String {
                log("✅ Status checked: \(status)")
            }
        } catch {
            log("❌ Status check failed: \(error.localizedDescription)")
        }
    }
    
  
    
    private func log(_ message: String) {
        print(message)
        Task { @MainActor in
            logStore.add(message)
        }
    }
    
    // MARK: - Download Handling from APNS
    
    /// Start download from APNS push notification
    /// ✅ Creates download marked as isFromAPNS=true so it won't be re-queued
    /// ✅ Saves to database FIRST, then starts download
    private func startDownloadFromAPNS(payload: [AnyHashable: Any]) async {
        // Extract download details from payload
        guard let url = payload["download_url"] as? String,
              let fileName = payload["file_name"] as? String else {
            log("❌ Invalid download payload: missing download_url or file_name")
            return
        }
         
        let fileSize = payload["file_size"] as? Int64 ?? 0
        log("📥 APNS Download request: \(fileName) (\(formatBytes(fileSize)))")
         
        do {
            // ✅ STEP 1: Create and save to SwiftData FIRST
            // Use createFileDownloadFromAPNS to mark as APNS and prevent re-queuing
            let dataStore = SwiftDataManager.shared.dataStore
            let fileDownload = try dataStore.createFileDownloadFromAPNS(
                url: url,
                fileName: fileName,
                fileSize: fileSize
            )
            log("✅ Download saved to database (APNS - won't be queued): \(fileDownload.id)")
             
            // ✅ STEP 2: Now start the download
            let downloadManager = FileDownloadManager.shared
            downloadManager.dataStoreProvider = { dataStore }
            downloadManager.startDownload(fileDownload)
            log("✅ Download started from APNS: \(fileName)")
             
        } catch {
            log("❌ Error creating download from APNS: \(error.localizedDescription)")
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    /// Start test download from notification
    /// Must be called with DataStore available
    func startTestDownload(with dataStore: DataStore) {
        do {
            // ✅ STEP 1: Create and save to database FIRST
            let fileDownload = try dataStore.createFileDownload(
                url: "https://proof.ovh.net/files/10Mb.dat",
                fileName: "Test File (10MB)",
                fileSize: 1024 * 1024 * 10,
                isFromAPNS: true,
            )
            log("✅ Test download saved to database: \(fileDownload.id)")
            
            // ✅ STEP 2: Now start the download
            let downloadManager = FileDownloadManager.shared
            downloadManager.dataStoreProvider = { dataStore }
            downloadManager.startDownload(fileDownload)
            log("✅ Test download started: Test File (10MB)")
            
        } catch {
            log("❌ Error starting test download: \(error.localizedDescription)")
        }
    }
}
