//
//  MVVMUserListView.swift
//  ArchLearning
//
//  View for the plain MVVM demo screen. Structurally identical to
//  CleanUserListView (same ViewState rendering), but driven by
//  MVVMUserListViewModel, which embeds its own networking + SwiftData
//  logic instead of delegating to a repository/use case.
//

import SwiftUI
import SwiftData

struct MVVMUserListView: View {
    @State private var viewModel: MVVMUserListViewModel

    init(viewModel: MVVMUserListViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        content
            .navigationTitle("MVVM Only")
            .task { await viewModel.onAppear() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView("Loading users…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error(let message):
            ContentUnavailableView {
                Label("Something went wrong", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Retry") {
                    Task { await viewModel.refresh() }
                }
            }
        case .loaded(let users):
            List(users) { user in
                UserRowView(user: user)
            }
            .refreshable { await viewModel.refresh() }
            .overlay(alignment: .top) {
                if viewModel.isRefreshing {
                    ProgressView().padding(.top, 4)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        MVVMUserListView(
            viewModel: MVVMUserListViewModel(
                service: ReqResUserService(),
                modelContext: try! ModelContainer(for: UserRecord.self, configurations: .init(isStoredInMemoryOnly: true)).mainContext
            )
        )
    }
}
