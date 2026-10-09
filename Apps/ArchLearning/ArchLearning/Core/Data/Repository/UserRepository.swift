//
//  UserRepository.swift
//  ArchLearning
//
//  Clean Architecture "Data" layer. Coordinates between the remote and
//  local data sources and decides the caching policy. The repository is
//  the single injection point for swapping data sources (SwiftData <->
//  something else, reqres.in <-> plist, etc.) without touching the
//  domain (use cases) or presentation (view models) layers.
//

import Foundation

protocol UserRepositoryProtocol: Sendable {
    func getUsers(forceRefresh: Bool) async throws -> [UserEntity]
}

final class UserRepository: UserRepositoryProtocol {
    private let remote: RemoteUserDataSource
    private let local: LocalUserDataSource

    init(remote: RemoteUserDataSource, local: LocalUserDataSource) {
        self.remote = remote
        self.local = local
    }

    /// Cache-first by default. Pass `forceRefresh: true` (e.g. pull-to-refresh)
    /// to always hit the remote source and overwrite the local cache.
    func getUsers(forceRefresh: Bool) async throws -> [UserEntity] {
        if !forceRefresh {
            let cached = try await local.fetchCachedUsers()
            if !cached.isEmpty {
                return cached
            }
        }

        let remoteUsers = try await remote.fetchUsers()
        try await local.save(remoteUsers)
        return remoteUsers
    }
}
