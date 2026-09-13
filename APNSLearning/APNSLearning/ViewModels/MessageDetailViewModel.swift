//
//  MessageDetailViewModel.swift
//  APNSLearning
//
//  Created by Ashish Awasthi on 13/09/26.
//

import Foundation
import Combine

@MainActor
class MessageDetailViewModel: ObservableObject {
    @Published var message: APNSMessage
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let repository: MessageRepository
    
    init(message: APNSMessage, repository: MessageRepository) {
        self.message = message
        self.repository = repository
        Task {
            await markAsRead()
        }
    }
    
    func markAsRead() async {
        guard let id = message.id else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await repository.markMessageAsRead(id: id)
            message.isRead = true
        } catch {
            errorMessage = "Failed to mark message as read: \(error.localizedDescription)"
        }
    }
    
    func deleteMessage() async {
        guard let id = message.id else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await repository.deleteMessage(id: id)
        } catch {
            errorMessage = "Failed to delete message: \(error.localizedDescription)"
        }
    }
}
