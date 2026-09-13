//
//  OfflineService.swift
//  APNSLearning
//
//  Created by Ashish Awasthi on 13/09/26.
//

import Foundation
import CoreData

protocol OfflineService: Sendable {
    func saveMessage(_ message: APNSMessageDTO) async throws
    func fetchAllMessages() async throws -> [APNSMessage]
    func fetchUnreadMessages() async throws -> [APNSMessage]
    func fetchReadMessages() async throws -> [APNSMessage]
    func markMessageAsRead(id: String) async throws
    func deleteMessage(id: String) async throws
}

class CoreDataOfflineService: OfflineService {
    private let persistenceController: PersistenceController
    
    init(persistenceController: PersistenceController) {
        self.persistenceController = persistenceController
    }
    
    nonisolated func saveMessage(_ message: APNSMessageDTO) async throws {
        let viewContext = persistenceController.container.viewContext
        
        try await viewContext.perform {
            let apnsMessage = APNSMessage(context: viewContext)
            apnsMessage.id = message.id
            apnsMessage.title = message.title
            apnsMessage.body = message.body
            apnsMessage.receivedAt = message.receivedAt
            apnsMessage.payload = message.payload
            apnsMessage.isRead = false
            
            try viewContext.save()
        }
    }
    
    nonisolated func fetchAllMessages() async throws -> [APNSMessage] {
        let viewContext = persistenceController.container.viewContext
        let fetchRequest = APNSMessage.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \APNSMessage.receivedAt, ascending: false)]
        
        var result: [APNSMessage] = []
        try await viewContext.perform {
            result = try viewContext.fetch(fetchRequest)
        }
        return result
    }
    
    nonisolated func fetchUnreadMessages() async throws -> [APNSMessage] {
        let viewContext = persistenceController.container.viewContext
        let fetchRequest = APNSMessage.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isRead == false")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \APNSMessage.receivedAt, ascending: false)]
        
        var result: [APNSMessage] = []
        try await viewContext.perform {
            result = try viewContext.fetch(fetchRequest)
        }
        return result
    }
    
    nonisolated func fetchReadMessages() async throws -> [APNSMessage] {
        let viewContext = persistenceController.container.viewContext
        let fetchRequest = APNSMessage.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isRead == true")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \APNSMessage.receivedAt, ascending: false)]
        
        var result: [APNSMessage] = []
        try await viewContext.perform {
            result = try viewContext.fetch(fetchRequest)
        }
        return result
    }
    
    nonisolated func markMessageAsRead(id: String) async throws {
        let viewContext = persistenceController.container.viewContext
        let fetchRequest = APNSMessage.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id)
        
        try await viewContext.perform {
            if let message = try viewContext.fetch(fetchRequest).first {
                message.isRead = true
                try viewContext.save()
            }
        }
    }
    
    nonisolated func deleteMessage(id: String) async throws {
        let viewContext = persistenceController.container.viewContext
        let fetchRequest = APNSMessage.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id)
        
        try await viewContext.perform {
            if let message = try viewContext.fetch(fetchRequest).first {
                viewContext.delete(message)
                try viewContext.save()
            }
        }
    }
}
