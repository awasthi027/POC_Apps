//
//  CleanMVPUserListView.swift
//  ArchLearning
//
//  View for the Clean Architecture + MVP demo. Same rendering as
//  MVPUserListView, driven by CleanUserListPresenter instead — proving the
//  View/state-store plumbing is identical between MVP-only and Clean+MVP;
//  only the Presenter's data dependency (UseCase vs raw service) differs.
//

import SwiftUI
import SwiftData

struct CleanMVPUserListView: View {
    @StateObject private var store = MVPViewStateStore()
    let presenter: CleanUserListPresenter

    init(presenter: CleanUserListPresenter) {
        self.presenter = presenter
    }

    var body: some View {
        content
            .navigationTitle("Clean + MVP")
            .task {
                presenter.attach(view: store)
                await presenter.onAppear()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch store.state {
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
                    Task { await presenter.onRefresh() }
                }
            }
        case .loaded(let users):
            List(users) { user in
                UserRowView(user: user)
            }
            .refreshable { await presenter.onRefresh() }
            .overlay(alignment: .top) {
                if store.isRefreshing {
                    ProgressView().padding(.top, 4)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        CleanMVPUserListView(
            presenter: CleanUserListPresenter(
                fetchUsersUseCase: FetchUsersUseCase(
                    repository: UserRepository(
                        remote: PlistUserDataSource(),
                        local: PreviewCleanMVPLocalDataSource()
                    )
                )
            )
        )
    }
}

/// Lightweight in-memory local data source used purely for SwiftUI previews.
private actor PreviewCleanMVPLocalDataSource: LocalUserDataSource {
    func fetchCachedUsers() async throws -> [UserEntity] { [] }
    func save(_ users: [UserEntity]) async throws {}
    func clearAll() async throws {}
}
