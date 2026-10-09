//
//  MockDataSources.swift
//  ArchLearningTests
//
//  Shared in-memory fakes used across the test suite to avoid real
//  network/SwiftData calls.
//

import Foundation
@testable import ArchLearning

final class MockRemoteUserDataSource: RemoteUserDataSource, @unchecked Sendable {
    var usersToReturn: [UserEntity] = []
    var errorToThrow: Error?
    private(set) var fetchCallCount = 0

    func fetchUsers() async throws -> [UserEntity] {
        fetchCallCount += 1
        if let errorToThrow {
            throw errorToThrow
        }
        return usersToReturn
    }
}

final class MockLocalUserDataSource: LocalUserDataSource, @unchecked Sendable {
    var cachedUsers: [UserEntity] = []
    private(set) var saveCallCount = 0
    private(set) var clearCallCount = 0

    func fetchCachedUsers() async throws -> [UserEntity] {
        cachedUsers
    }

    func save(_ users: [UserEntity]) async throws {
        saveCallCount += 1
        cachedUsers = users
    }

    func clearAll() async throws {
        clearCallCount += 1
        cachedUsers = []
    }
}

final class MockFetchUsersUseCase: FetchUsersUseCaseProtocol, @unchecked Sendable {
    var usersToReturn: [UserEntity] = []
    var errorToThrow: Error?
    private(set) var executeCalls: [Bool] = []

    func execute(forceRefresh: Bool) async throws -> [UserEntity] {
        executeCalls.append(forceRefresh)
        if let errorToThrow {
            throw errorToThrow
        }
        return usersToReturn
    }
}

struct MockEndpointProvider: EndpointProviding {
    var urlsByKey: [EndpointKey: URL] = [:]
    var errorToThrow: Error?

    func url(for key: EndpointKey) throws -> URL {
        if let errorToThrow {
            throw errorToThrow
        }
        guard let url = urlsByKey[key] else {
            throw EndpointProviderError.keyNotFound(key.rawValue)
        }
        return url
    }
}

final class MockUserService: UserService, @unchecked Sendable {
    var usersToReturn: [UserEntity] = []
    var errorToThrow: Error?
    private(set) var fetchCallCount = 0

    func fetchUsers() async throws -> [UserEntity] {
        fetchCallCount += 1
        if let errorToThrow {
            throw errorToThrow
        }
        return usersToReturn
    }
}

struct StubError: Error, Equatable {
    let message: String
}

/// Captures every state/refresh push made by a Presenter, so MVP tests can
/// assert on the exact sequence without any SwiftUI involved.
@MainActor
final class MockUserListView: UserListViewProtocol {
    private(set) var displayedStates: [UserListViewState] = []
    private(set) var refreshingValues: [Bool] = []

    var latestState: UserListViewState? { displayedStates.last }

    func display(state: UserListViewState) {
        displayedStates.append(state)
    }

    func setRefreshing(_ isRefreshing: Bool) {
        refreshingValues.append(isRefreshing)
    }
}

enum TestFixtures {
    static let user1 = UserEntity(
        id: 1,
        email: "george.bluth@reqres.in",
        firstName: "George",
        lastName: "Bluth",
        avatarURL: URL(string: "https://reqres.in/img/faces/1-image.jpg")
    )

    static let user2 = UserEntity(
        id: 2,
        email: "janet.weaver@reqres.in",
        firstName: "Janet",
        lastName: "Weaver",
        avatarURL: URL(string: "https://reqres.in/img/faces/2-image.jpg")
    )
}
