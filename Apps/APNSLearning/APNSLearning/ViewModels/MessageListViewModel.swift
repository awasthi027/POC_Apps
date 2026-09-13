//
//  MessageListViewModel.swift
//  APNSLearning
//
//  Created by Ashish Awasthi on 13/09/26.
//

import Foundation
import CoreData
import SwiftUI
import Combine

enum MessageFilter {
    case all
    case read
    case unread
}

@MainActor
class MessageListViewModel: ObservableObject {
    @Published var messages: [APNSMessage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedFilter: MessageFilter = .all {
        didSet {
            objectWillChange.send()
        }
    }
    
    private let repository: MessageRepository
    private var fetchedResultsController: NSFetchedResultsController<APNSMessage>?
    private var cancellables = Set<AnyCancellable>()
    
    init(repository: MessageRepository) {
        self.repository = repository
        setupFetchedResultsController()
        Task {
            await loadMessages()
        }
    }
    
    func loadMessages() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            try performFetch()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func performFetch() throws {
        guard let fetchedResultsController = fetchedResultsController else { return }
        
        try fetchedResultsController.performFetch()
        messages = fetchedResultsController.fetchedObjects ?? []
    }
    
    private func setupFetchedResultsController() {
        let persistenceController = PersistenceController.shared
        let fetchRequest = APNSMessage.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \APNSMessage.receivedAt, ascending: false)]
        
        let controller = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: persistenceController.container.viewContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        
        self.fetchedResultsController = controller
        
        let observer = NotificationCenter.default.publisher(for: NSManagedObjectContext.didChangeObjectsNotification,
                                                           object: persistenceController.container.viewContext)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    try? self?.performFetch()
                }
            }
        
        cancellables.insert(observer)
    }
    
    func filterMessages() -> [APNSMessage] {
        switch selectedFilter {
        case .all:
            return messages
        case .read:
            return messages.filter { $0.isRead }
        case .unread:
            return messages.filter { !$0.isRead }
        }
    }
    
    func markAsRead(_ message: APNSMessage) async {
        guard let id = message.id else { return }
        
        do {
            try await repository.markMessageAsRead(id: id)
            try performFetch()
        } catch {
            errorMessage = "Failed to mark message as read: \(error.localizedDescription)"
        }
    }
    
    func deleteMessage(_ message: APNSMessage) async {
        guard let id = message.id else { return }
        
        do {
            try await repository.deleteMessage(id: id)
            try performFetch()
        } catch {
            errorMessage = "Failed to delete message: \(error.localizedDescription)"
        }
    }
}

