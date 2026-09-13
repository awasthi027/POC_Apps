//
//  BaseView.swift
//  APNSLearning
//
//  Created by Ashish Awasthi on 13/09/26.
//

import SwiftUI
import CoreData

struct BaseView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var unreadCount = 0
    @State private var showUnreadAlert = false
    let messageRepository: MessageRepository

    var body: some View {
        TabView {
            MessageListView(repository: messageRepository)
                .tabItem {
                    Label("Messages", systemImage: "envelope.fill")
                }

            LogsView()
                .tabItem {
                    Label("Logs", systemImage: "doc.text")
                }
        }
        .onAppear {
            setupAppActiveNotification()
        }
        .alert("Unread Messages", isPresented: $showUnreadAlert) {
            Button("OK") {
                showUnreadAlert = false
            }
        } message: {
            Text("You have \(unreadCount) unread message\(unreadCount == 1 ? "" : "s").")
        }
    }
    
    private func setupAppActiveNotification() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task {
                await checkAndShowUnreadAlert()
            }
        }
    }
    
    private func checkAndShowUnreadAlert() async {
        do {
            let count = try await messageRepository.getUnreadMessageCount()
            APNSLogStore.shared.add("Application become active: \(count)")
            if count > 0 {
                self.unreadCount = count
                self.showUnreadAlert = true
            }
        } catch {
            print("❌ Error fetching unread count: \(error)")
        }
    }
}

#Preview {
    BaseView(
        messageRepository: MessageRepository(
            onlineService: DefaultOnlineService(),
            offlineService: CoreDataOfflineService(persistenceController: PersistenceController.preview)
        )
    )
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
