//
//  BGTaskLearningApp.swift
//  BGTaskLearning
//
//  Created by Ashish Awasthi on 18/09/26.
//

import SwiftUI
import SwiftData

@main
struct BGTaskLearningApp: App {
    @Environment(\.scenePhase) var scenePhase
    @State private var downloadsViewModel: DownloadsViewModel?
    @UIApplicationDelegateAdaptor(APNSDelegate.self) private var apnsDelegate
    @State private var apnsSetupDone = false
    
    private let swiftDataManager = SwiftDataManager.shared

    var body: some Scene {
        WindowGroup {
            DownloadsView()
                .modelContainer(swiftDataManager.modelContainer)
                .onAppear {
                    requestNotificationPermission()
                }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
    }
    
    
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            print("App went to background - starting queued downloads")
            let downloadQueue = DownloadQueueService(dataStore: swiftDataManager.dataStore)
            
            // Set the dataStore provider for FileDownloadManager
            FileDownloadManager.shared.dataStoreProvider = { swiftDataManager.dataStore }
            
            downloadQueue.startQueueProcessing()
        case .active:
            print("App came to foreground")
        case .inactive:
            break
        @unknown default:
            break
        }
    }
    private func requestNotificationPermission() {
        Task {
            _ = await APNSManager.shared.requestUserPermission()
        }
    }
}
