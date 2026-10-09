//
//  CleanUserListViewModel.swift
//  ArchLearning
//
//  Presentation layer for the Clean Architecture + MVVM demo screen.
//  The view model only knows about the use case protocol — it has no idea
//  whether data comes from reqres.in, SwiftData, or a .plist file.
//

import Foundation
import Observation

@MainActor
@Observable
final class CleanUserListViewModel {
    enum ViewState: Equatable {
        case idle
        case loading
        case loaded([UserEntity])
        case error(String)
    }

    private(set) var state: ViewState = .idle
    private(set) var isRefreshing = false

    private let fetchUsersUseCase: FetchUsersUseCaseProtocol

    init(fetchUsersUseCase: FetchUsersUseCaseProtocol) {
        self.fetchUsersUseCase = fetchUsersUseCase
    }

    /// Called when the view first appears. Uses the cache-first policy.
    func onAppear() async {
        guard state == .idle else { return }
        await load(forceRefresh: false)
    }

    /// Called from pull-to-refresh. Always hits the remote source.
    func refresh() async {
        isRefreshing = true
        await load(forceRefresh: true)
        isRefreshing = false
    }

    private func load(forceRefresh: Bool) async {
        if !forceRefresh {
            state = .loading
        }
        do {
            let users = try await fetchUsersUseCase.execute(forceRefresh: forceRefresh)
            state = .loaded(users)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}
