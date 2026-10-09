//
//  MVVMUserListViewModelTests.swift
//  ArchLearningTests
//
//  Verifies the MVVM-only view model, which talks to UserService and an
//  in-memory SwiftData ModelContext directly (no repository layer).
//

import Testing
import SwiftData
@testable import ArchLearning

@MainActor
struct MVVMUserListViewModelTests {
    private func makeInMemoryContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: UserRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @Test func onAppearFetchesFromServiceWhenCacheIsEmpty() async throws {
        let service = MockUserService()
        service.usersToReturn = [TestFixtures.user1]
        let context = try makeInMemoryContext()
        let sut = MVVMUserListViewModel(service: service, modelContext: context)

        await sut.onAppear()

        #expect(sut.state == .loaded([TestFixtures.user1]))
        #expect(service.fetchCallCount == 1)
    }

    @Test func onAppearUsesSwiftDataCacheWhenPresent() async throws {
        let service = MockUserService()
        let context = try makeInMemoryContext()
        context.insert(UserRecord(entity: TestFixtures.user2))
        try context.save()

        let sut = MVVMUserListViewModel(service: service, modelContext: context)

        await sut.onAppear()

        #expect(sut.state == .loaded([TestFixtures.user2]))
        #expect(service.fetchCallCount == 0)
    }

    @Test func refreshAlwaysFetchesFromServiceAndPersists() async throws {
        let service = MockUserService()
        service.usersToReturn = [TestFixtures.user1, TestFixtures.user2]
        let context = try makeInMemoryContext()
        context.insert(UserRecord(entity: TestFixtures.user1))
        try context.save()

        let sut = MVVMUserListViewModel(service: service, modelContext: context)
        await sut.refresh()

        #expect(sut.state == .loaded([TestFixtures.user1, TestFixtures.user2]))
        #expect(service.fetchCallCount == 1)

        let descriptor = FetchDescriptor<UserRecord>()
        let saved = try context.fetch(descriptor)
        #expect(saved.count == 2)
    }

    @Test func onAppearSetsErrorStateOnServiceFailure() async throws {
        let service = MockUserService()
        service.errorToThrow = StubError(message: "boom")
        let context = try makeInMemoryContext()
        let sut = MVVMUserListViewModel(service: service, modelContext: context)

        await sut.onAppear()

        guard case .error = sut.state else {
            Issue.record("Expected error state, got \(sut.state)")
            return
        }
    }
}
