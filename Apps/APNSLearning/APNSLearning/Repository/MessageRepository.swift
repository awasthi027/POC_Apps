//
//  MessageRepository.swift
//  APNSLearning
//
//  Created by Ashish Awasthi on 13/09/26.
//

import Foundation

class MessageRepository {
    private let onlineService: OnlineService
    private let offlineService: OfflineService
    
    init(onlineService: OnlineService, offlineService: OfflineService) {
        self.onlineService = onlineService
        self.offlineService = offlineService
    }
    
    func fetchAllMessages() async throws -> [APNSMessage] {
        return try await offlineService.fetchAllMessages()
    }
    
    func fetchUnreadMessages() async throws -> [APNSMessage] {
        return try await offlineService.fetchUnreadMessages()
    }
    
    func getUnreadMessageCount() async throws -> Int {
        let unreadMessages = try await offlineService.fetchUnreadMessages()
        return unreadMessages.count
    }
    
    func fetchReadMessages() async throws -> [APNSMessage] {
        return try await offlineService.fetchReadMessages()
    }
    
    func markMessageAsRead(id: String) async throws {
        try await offlineService.markMessageAsRead(id: id)
        try await onlineService.markMessageAsRead(id: id)
    }
    
    func deleteMessage(id: String) async throws {
        try await offlineService.deleteMessage(id: id)
    }
    
    func storeNotificationIfNeeded(payload: [AnyHashable: Any]) async throws {
        let id = UUID().uuidString
        let title = (payload["aps"] as? [String: Any])?["alert"] as? String ?? "Notification"
        let body = (payload["aps"] as? [String: Any])?["alert"] as? String ?? ""
        let receivedAt = Date()
        let payloadString = String(describing: payload)
        
        let message = APNSMessageDTO(
            id: id,
            title: title,
            body: body,
            receivedAt: receivedAt,
            payload: payloadString
        )
        
        try await offlineService.saveMessage(message)
    }
}
