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
                Section("1) Secure Channel") {
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
                }

                Section("2) Create Article") {
                    TextField("Article title", text: $viewModel.articleCreateViewModel.articleTitle)
                        .textFieldStyle(.roundedBorder)
                    TextField("Article description", text: $viewModel.articleCreateViewModel.articleDescription)
                        .textFieldStyle(.roundedBorder)

                    Button(viewModel.articleCreateViewModel.isRequestInProgress ? "Creating..." : "Create Article") {
                        viewModel.articleCreateViewModel.createArticle()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.isSecureChannelActive || viewModel.articleCreateViewModel.isRequestInProgress)

                    if !viewModel.articleCreateViewModel.status.isEmpty {
                        Text(viewModel.articleCreateViewModel.status)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("3) Articles") {
                    Button(viewModel.articleListViewModel.isRequestInProgress ? "Refreshing..." : "Refresh Articles") {
                        viewModel.articleListViewModel.loadArticles()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.isSecureChannelActive || viewModel.articleListViewModel.isRequestInProgress)

                    if viewModel.articleListViewModel.articles.isEmpty {
                        Text("No articles yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.articleListViewModel.articles) { article in
                            NavigationLink {
                                ArticleDetailView(viewModel: viewModel.makeArticleDetailViewModel(articleId: article.id))
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(article.title)
                                        .font(.headline)
                                    Text("ID: \(article.id)")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    Text(viewModel.articleListViewModel.status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Secure Articles")
        }
    }
}

#Preview {
    SecureChannelView()
}
