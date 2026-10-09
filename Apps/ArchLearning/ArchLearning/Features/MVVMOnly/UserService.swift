//
//  UserService.swift
//  ArchLearning
//
//  MVVM-only demo: no repository / use case abstraction on top. The
//  service is a thin networking wrapper and the view model below talks to
//  it (and to SwiftData) directly. Contrast this with the Clean + MVVM
//  screen, which inserts a Repository + UseCase layer between the view
//  model and the data sources.
//

import Foundation

protocol UserService: Sendable {
    func fetchUsers() async throws -> [UserEntity]
}

struct ReqResUserService: UserService {
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
