//
//  APNSLearningApp.swift
//  APNSLearning
//
//  Created by Ashish Awasthi on 13/09/26.
//

import SwiftUI
import CoreData
import UserNotifications

@main
struct APNSLearningApp: App {
    let persistenceController = PersistenceController.shared
    @UIApplicationDelegateAdaptor(APNSDelegate.self) private var apnsDelegate
    let messageRepository: MessageRepository
    
    init() {
        let onlineService = DefaultOnlineService()
        let offlineService = CoreDataOfflineService(persistenceController: persistenceController)
        let repository = MessageRepository(onlineService: onlineService, offlineService: offlineService)
        self.messageRepository = repository
        apnsDelegate.messageRepository = repository
    }

    var body: some Scene {
        WindowGroup {
            BaseView(messageRepository: messageRepository)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onAppear {
                    apnsDelegate.messageRepository = messageRepository
                    requestNotificationPermission()
                }
        }
    }
    
    private func requestNotificationPermission() {
        Task {
            _ = await APNSManager.shared.requestUserPermission()
        }
    }
}
