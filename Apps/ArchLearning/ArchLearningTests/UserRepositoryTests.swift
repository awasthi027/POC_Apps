//
//  UserRepositoryTests.swift
//  ArchLearningTests
//
//  Verifies the Clean Architecture repository's cache-first policy and
//  forced-refresh behavior using mock data sources.
//

import Testing
@testable import ArchLearning

struct UserRepositoryTests {
    @Test func returnsCachedUsersWhenAvailableAndNotForcingRefresh() async throws {
        let remote = MockRemoteUserDataSource()
        let local = MockLocalUserDataSource()
        local.cachedUsers = [TestFixtures.user1]
        let repository = await UserRepository(remote: remote, local: local)

        let result = try await repository.getUsers(forceRefresh: false)

        #expect(result == [TestFixtures.user1])
        #expect(remote.fetchCallCount == 0)
    }

    @Test func fetchesRemoteWhenCacheIsEmpty() async throws {
        let remote = MockRemoteUserDataSource()
        remote.usersToReturn = [TestFixtures.user1, TestFixtures.user2]
        let local = MockLocalUserDataSource()
        let repository = await UserRepository(remote: remote, local: local)

        let result = try await repository.getUsers(forceRefresh: false)

        #expect(result == [TestFixtures.user1, TestFixtures.user2])
        #expect(remote.fetchCallCount == 1)
        #expect(local.saveCallCount == 1)
        #expect(local.cachedUsers == [TestFixtures.user1, TestFixtures.user2])
    }

    @Test func forceRefreshAlwaysHitsRemoteEvenWithCache() async throws {
        let remote = MockRemoteUserDataSource()
        remote.usersToReturn = [TestFixtures.user2]
        let local = MockLocalUserDataSource()
        local.cachedUsers = [TestFixtures.user1]
        let repository = await UserRepository(remote: remote, local: local)

        let result = try await repository.getUsers(forceRefresh: true)

        #expect(result == [TestFixtures.user2])
        #expect(remote.fetchCallCount == 1)
        #expect(local.saveCallCount == 1)
    }

    @Test func propagatesRemoteErrors() async {
        let remote = MockRemoteUserDataSource()
        remote.errorToThrow = StubError(message: "network down")
        let local = MockLocalUserDataSource()
        let repository = await UserRepository(remote: remote, local: local)

        await #expect(throws: StubError.self) {
            _ = try await repository.getUsers(forceRefresh: false)
        }
    }
}
