//
//  CleanUserListView.swift
//  ArchLearning
//
//  View for the Clean Architecture + MVVM demo. The view is dumb: it just
//  renders whatever state the view model publishes and forwards user
//  intents (appear / refresh) back to it.
//

import SwiftUI
import SwiftData

struct CleanUserListView: View {
    @State private var viewModel: CleanUserListViewModel

    init(viewModel: CleanUserListViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        content
            .navigationTitle("Clean + MVVM")
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
        CleanUserListView(
            viewModel: CleanUserListViewModel(
                fetchUsersUseCase: FetchUsersUseCase(
                    repository: UserRepository(
                        remote: PlistUserDataSource(),
                        local: PreviewLocalDataSource()
                    )
                )
            )
        )
    }
}

/// Lightweight in-memory local data source used purely for SwiftUI previews.
private actor PreviewLocalDataSource: LocalUserDataSource {
    func fetchCachedUsers() async throws -> [UserEntity] { [] }
    func save(_ users: [UserEntity]) async throws {}
    func clearAll() async throws {}
}
