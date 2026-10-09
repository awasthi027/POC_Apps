//
//  MVVMUserListViewModel.swift
//  ArchLearning
//
//  Plain MVVM: the view model owns both the networking call *and* the
//  SwiftData read/write logic itself, with no repository/use case layer
//  in between. This is simpler to write for a single screen, but couples
//  the view model to both SwiftData and the network, making it harder to
//  swap data sources or reuse the caching logic elsewhere later —
//  precisely the tradeoff the Clean + MVVM screen avoids.
//

import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class MVVMUserListViewModel {
    enum ViewState: Equatable {
        case idle
        case loading
        case loaded([UserEntity])
        case error(String)
    }

    private(set) var state: ViewState = .idle
    private(set) var isRefreshing = false

    private let service: UserService
    private let modelContext: ModelContext

    init(service: UserService? = nil, modelContext: ModelContext) {
        self.service = service ?? ReqResUserService()
        self.modelContext = modelContext
    }

    func onAppear() async {
        guard state == .idle else { return }
        state = .loading

        let cached = fetchFromSwiftData()
        if !cached.isEmpty {
            state = .loaded(cached)
            return
        }
        await fetchRemoteAndSave()
    }

    func refresh() async {
        isRefreshing = true
        await fetchRemoteAndSave()
        isRefreshing = false
    }

    private func fetchRemoteAndSave() async {
        do {
            let users = try await service.fetchUsers()
            saveToSwiftData(users)
            state = .loaded(users)
        } catch {
            state = .error(error.localizedDescription)
        }
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
