//
//  FetchUsersUseCase.swift
//  ArchLearning
//
//  Clean Architecture "Domain" layer. Encapsulates a single application
//  business rule ("fetch the list of users, optionally forcing a refresh")
//  behind a protocol so the presentation layer (view model) never talks to
//  the repository/data sources directly.
//

import Foundation

protocol FetchUsersUseCaseProtocol: Sendable {
    func execute(forceRefresh: Bool) async throws -> [UserEntity]
}

struct FetchUsersUseCase: FetchUsersUseCaseProtocol {
    private let repository: UserRepositoryProtocol

    init(repository: UserRepositoryProtocol) {
        self.repository = repository
    }

    func execute(forceRefresh: Bool) async throws -> [UserEntity] {
        try await repository.getUsers(forceRefresh: forceRefresh)
    }
}
