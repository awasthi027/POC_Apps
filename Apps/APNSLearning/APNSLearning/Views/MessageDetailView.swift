//
//  MessageDetailView.swift
//  APNSLearning
//
//  Created by Ashish Awasthi on 13/09/26.
//

import SwiftUI
import CoreData

struct MessageDetailView: View {
    @StateObject private var viewModel: MessageDetailViewModel
    @Environment(\.dismiss) var dismiss
    
    private let message: APNSMessage
    private let repository: MessageRepository
    
    init(message: APNSMessage, repository: MessageRepository) {
        self.message = message
        self.repository = repository
        _viewModel = StateObject(wrappedValue: MessageDetailViewModel(message: message, repository: repository))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(viewModel.message.title ?? "Notification")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        HStack {
                            Text(viewModel.message.receivedAt?.formatted(date: .abbreviated, time: .shortened) ?? "")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            if viewModel.message.isRead {
                                Label("Read", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else {
                                Label("Unread", systemImage: "circle")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    Spacer()
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Message")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    Text(viewModel.message.body ?? "No content")
                        .font(.body)
                        .lineSpacing(4)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Payload")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    Text(viewModel.message.payload ?? "No payload")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(4)
                }
                
                Spacer()
                
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color(.systemRed).opacity(0.1))
                        .cornerRadius(4)
                }
                
                HStack(spacing: 12) {
                    if !viewModel.message.isRead {
                        Button(action: {
                            Task {
                                await viewModel.markAsRead()
                            }
                        }) {
                            HStack {
                                Image(systemName: "checkmark")
                                Text("Mark as Read")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(viewModel.isLoading)
                    }
                    
                    Button(role: .destructive, action: {
                        Task {
                            await viewModel.deleteMessage()
                            dismiss()
                        }
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemRed))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .padding()
        }
        .navigationTitle("Message Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    let repository = MessageRepository(
        onlineService: DefaultOnlineService(),
        offlineService: CoreDataOfflineService(persistenceController: PersistenceController.preview)
    )
    
    let context = PersistenceController.preview.container.viewContext
    let message = APNSMessage(context: context)
    message.id = UUID().uuidString
    message.title = "Test Message"
    message.body = "This is a test message for preview"
    message.receivedAt = Date()
    message.payload = "{\"test\": true}"
    message.isRead = false
    
    return NavigationView {
        MessageDetailView(message: message, repository: repository)
    }
}
