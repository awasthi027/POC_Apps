//
//  MVPUserListPresenter.swift
//  ArchLearning
//
//  Plain MVP: like MVVMUserListViewModel, the Presenter owns both the
//  networking call *and* the SwiftData read/write logic directly (no
//  repository/use case layer). The difference from MVVM is structural,
//  not architectural-layering: instead of exposing @Observable state the
//  View reactively binds to, the Presenter holds a weak reference to a
//  passive `UserListViewProtocol` and *pushes* state to it imperatively.
//

import Foundation
import SwiftData

@MainActor
final class MVPUserListPresenter {
    private weak var view: UserListViewProtocol?
    private let service: UserService
    private let modelContext: ModelContext
    private var currentState: UserListViewState = .idle

    init(service: UserService? = nil, modelContext: ModelContext) {
        self.service = service ?? ReqResUserService()
        self.modelContext = modelContext
    }

    /// Attaches the passive view and immediately replays the current state,
    /// so a newly-appearing view is in sync even if `onAppear` already ran.
    func attach(view: UserListViewProtocol) {
        self.view = view
        view.display(state: currentState)
    }

    func onAppear() async {
        guard currentState == .idle else { return }
        update(.loading)

        let cached = fetchFromSwiftData()
        if !cached.isEmpty {
            update(.loaded(cached))
            return
        }
        await fetchRemoteAndSave()
    }

    func onRefresh() async {
        view?.setRefreshing(true)
        await fetchRemoteAndSave()
        view?.setRefreshing(false)
    }

    private func fetchRemoteAndSave() async {
        do {
            let users = try await service.fetchUsers()
            saveToSwiftData(users)
            update(.loaded(users))
        } catch {
            update(.error(error.localizedDescription))
        }
    }

    private func update(_ state: UserListViewState) {
        currentState = state
        view?.display(state: state)
    }

    private func fetchFromSwiftData() -> [UserEntity] {
        let descriptor = FetchDescriptor<UserRecord>(sortBy: [SortDescriptor(\.id)])
        let records = (try? modelContext.fetch(descriptor)) ?? []
        return records.map { $0.toEntity() }
    }

    private func saveToSwiftData(_ users: [UserEntity]) {
        let existing = (try? modelContext.fetch(FetchDescriptor<UserRecord>())) ?? []
        for record in existing {
            modelContext.delete(record)
        }
        for user in users {
            modelContext.insert(UserRecord(entity: user))
        }
        try? modelContext.save()
    }
}
