//
//  MessageListView.swift
//  APNSLearning
//
//  Created by Ashish Awasthi on 13/09/26.
//

import SwiftUI

struct MessageListView: View {
    @StateObject private var viewModel: MessageListViewModel
    @State private var selectedMessage: APNSMessage?
    
    private let repository: MessageRepository
    
    init(repository: MessageRepository) {
        self.repository = repository
        _viewModel = StateObject(wrappedValue: MessageListViewModel(repository: repository))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                Picker("Filter", selection: $viewModel.selectedFilter) {
                    Text("All").tag(MessageFilter.all)
                    Text("Unread").tag(MessageFilter.unread)
                    Text("Read").tag(MessageFilter.read)
                }
                .pickerStyle(.segmented)
                .padding()
                
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.filterMessages().isEmpty {
                    VStack {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No Messages")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewModel.filterMessages(), id: \.self) { message in
                            NavigationLink(destination: MessageDetailView(message: message, repository: repository)) {
                                MessageRowView(message: message)
                            }
                        }
                        .onDelete { indexSet in
                            Task {
                                for index in indexSet {
                                    let messages = viewModel.filterMessages()
                                    if index < messages.count {
                                        await viewModel.deleteMessage(messages[index])
                                    }
                                }
                            }
                        }
                    }
                }
                
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .navigationTitle("Messages")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
        }
    }
}

struct MessageRowView: View {
    let message: APNSMessage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.title ?? "Notification")
                        .font(.headline)
                        .fontWeight(message.isRead ? .regular : .bold)
                    
                    Text(message.body ?? "")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                
                Spacer()
                
                if !message.isRead {
                    Circle()
                        .fill(.blue)
                        .frame(width: 8, height: 8)
                }
            }
            
            HStack {
                Text(message.receivedAt?.formatted(date: .abbreviated, time: .shortened) ?? "")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text(message.isRead ? "Read" : "Unread")
                    .font(.caption)
                    .foregroundColor(message.isRead ? .gray : .blue)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    MessageListView(repository: MessageRepository(
        onlineService: DefaultOnlineService(),
        offlineService: CoreDataOfflineService(persistenceController: PersistenceController.preview)
    ))
}
