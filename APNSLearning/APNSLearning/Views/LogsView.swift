//
//  LogsView.swift
//  APNSLearning
//
//  Created by Ashish Awasthi on 13/09/26.
//

import SwiftUI

struct LogsView: View {
    @State private var apnsToken: String = "Not registered yet."
    @StateObject private var logStore = APNSLogStore.shared

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("APNS Token")) {
                    HStack(spacing: 12) {
                        Text(apnsToken)
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .lineLimit(2)
                            .truncationMode(.middle)
                            .textSelection(.enabled)

                        Spacer()

                        Button {
                            UIPasteboard.general.string = apnsToken
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }

                Section(header: Text("APNS Logs")) {
                    if logStore.logs.isEmpty {
                        Text("No logs yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(Array(logStore.logs.enumerated()), id: \.offset) { _, log in
                            Text(log)
                                .font(.caption2)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .navigationTitle("Logs")
            .onAppear {
                loadAPNSToken()
                observeTokenChanges()
            }
        }
    }

    private func loadAPNSToken() {
        apnsToken = UserDefaults.standard.string(forKey: "apnsDeviceToken") ?? "Not registered yet."
    }

    private func observeTokenChanges() {
        NotificationCenter.default.addObserver(
            forName: APNSDelegate.apnsTokenDidChange,
            object: nil,
            queue: .main
        ) { notification in
            if let token = notification.object as? String {
                apnsToken = token
            }
        }
    }
}

#Preview {
    LogsView()
}
