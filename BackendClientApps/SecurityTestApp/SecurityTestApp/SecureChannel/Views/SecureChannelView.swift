//
//  SecureChannelView.swift
//  SecurityTestApp
//
//  Created by Ashish Awasthi on 13/06/26.
//

import SwiftUI

struct SecureChannelView: View {
    @StateObject private var viewModel = SecureChannelViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section("Secure Channel") {
                    Text(viewModel.handshakeStatus)
                        .foregroundStyle(viewModel.isSecureChannelComplete ? .green : .primary)

                    if !viewModel.activeSessionId.isEmpty {
                        Text("Session ID: \(viewModel.activeSessionId)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Button(viewModel.isHandshakeInProgress ? "Setting Up..." : "Setup Secure Channel") {
                        viewModel.runFullEcdhHandshake()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isHandshakeInProgress)

                    Button(viewModel.isChannelStatusCheckInProgress ? "Checking Status..." : "Check Channel Active") {
                        viewModel.checkSecureChannelStatus()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.isSecureChannelComplete || viewModel.isChannelStatusCheckInProgress)

                    Text(viewModel.secureChannelStatus)
                        .font(.footnote)
                        .foregroundStyle(viewModel.isSecureChannelActive ? .green : .secondary)

                    if viewModel.isSecureChannelComplete {
                        Button("Forget Saved Channel") {
                            viewModel.clearSavedSecureChannel()
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }

                Section("Protected Features") {
                    NavigationLink {
                        ArticleCreateView(viewModel: viewModel.makeArticleCreateViewModel())
                    } label: {
                        Label("Create Article", systemImage: "square.and.pencil")
                    }
                    .disabled(!viewModel.isSecureChannelActive)

                    NavigationLink {
                        ArticleListView(
                            viewModel: viewModel.makeArticleListViewModel(),
                            detailViewModelFactory: { articleId in
                                viewModel.makeArticleDetailViewModel(articleId: articleId)
                            }
                        )
                    } label: {
                        Label("View Articles", systemImage: "list.bullet.rectangle")
                    }
                    .disabled(!viewModel.isSecureChannelActive)

                    if !viewModel.isSecureChannelActive {
                        Text("Complete setup and confirm the channel is active before opening article screens.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Secure Channel")
        }
    }
}

#Preview {
    SecureChannelView()
}
