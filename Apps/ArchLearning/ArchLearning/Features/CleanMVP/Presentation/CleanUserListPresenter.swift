//
//  CleanUserListPresenter.swift
//  ArchLearning
//
//  Clean Architecture's Presentation layer, this time shaped as MVP
//  instead of MVVM. Structurally identical to CleanUserListViewModel
//  (same single dependency on FetchUsersUseCaseProtocol, same caching/
//  refresh semantics) — only the state-delivery mechanism differs: this
//  Presenter pushes state to a passive `UserListViewProtocol` instead of
//  exposing @Observable properties.
//

import Foundation

@MainActor
final class CleanUserListPresenter {
    private weak var view: UserListViewProtocol?
    private let fetchUsersUseCase: FetchUsersUseCaseProtocol
    private var currentState: UserListViewState = .idle

    init(fetchUsersUseCase: FetchUsersUseCaseProtocol) {
        self.fetchUsersUseCase = fetchUsersUseCase
    }

    func attach(view: UserListViewProtocol) {
        self.view = view
        view.display(state: currentState)
    }

    func onAppear() async {
        guard currentState == .idle else { return }
        await load(forceRefresh: false)
    }

    func onRefresh() async {
        view?.setRefreshing(true)
        await load(forceRefresh: true)
        view?.setRefreshing(false)
    }

    private func load(forceRefresh: Bool) async {
        if !forceRefresh {
            update(.loading)
        }
        do {
            let users = try await fetchUsersUseCase.execute(forceRefresh: forceRefresh)
            update(.loaded(users))
        } catch {
            update(.error(error.localizedDescription))
        }
    }

    private func update(_ state: UserListViewState) {
        currentState = state
        view?.display(state: state)
    }
}
