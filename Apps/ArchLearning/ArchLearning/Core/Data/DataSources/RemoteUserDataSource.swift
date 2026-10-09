//
//  RemoteUserDataSource.swift
//  ArchLearning
//
//  Abstraction over "where do users come from remotely / externally".
//  Swapping RemoteUserAPIDataSource for PlistUserDataSource (or any future
//  source) is a single line change at the composition root — nothing in
//  the repository, use cases, or view models needs to change.
//

import Foundation

protocol RemoteUserDataSource: Sendable {
    func fetchUsers() async throws -> [UserEntity]
}

/// Default remote source. The endpoint URL is resolved at call time from
/// Endpoints.plist via `EndpointProvider` — never hardcoded here.
struct RemoteUserAPIDataSource: RemoteUserDataSource {
    let apiClient: APIClient
    let endpointProvider: EndpointProviding
    let endpointKey: EndpointKey

    init(
        apiClient: APIClient = URLSessionAPIClient(),
        endpointProvider: EndpointProviding = PlistEndpointProvider(),
        endpointKey: EndpointKey = .usersPage2
    ) {
        self.apiClient = apiClient
        self.endpointProvider = endpointProvider
        self.endpointKey = endpointKey
    }

    func fetchUsers() async throws -> [UserEntity] {
        let url = try endpointProvider.url(for: endpointKey)
        let response: UsersResponseDTO = try await apiClient.get(url)
        return response.data.map { $0.toEntity() }
    }
}
