//
//  MVPUserListView.swift
//  ArchLearning
//
//  View for the plain MVP demo screen. Owns an `MVPViewStateStore`
//  (@StateObject) that the Presenter pushes state into, then renders
//  reactively off that store — the push/pull boundary between Presenter
//  and View is explicit via `attach(view:)`.
//

import SwiftUI
import SwiftData

struct MVPUserListView: View {
    @StateObject private var store = MVPViewStateStore()
    let presenter: MVPUserListPresenter

    init(presenter: MVPUserListPresenter) {
        self.presenter = presenter
    }

    var body: some View {
        content
            .navigationTitle("MVP Only")
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
        MVPUserListView(
            presenter: MVPUserListPresenter(
                service: ReqResUserService(),
                modelContext: try! ModelContainer(for: UserRecord.self, configurations: .init(isStoredInMemoryOnly: true)).mainContext
            )
        )
    }
}
