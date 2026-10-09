//
//  MVPUserListPresenterTests.swift
//  ArchLearningTests
//
//  Verifies the MVP-only presenter, which talks to UserService and an
//  in-memory SwiftData ModelContext directly (no repository layer),
//  mirroring MVVMUserListViewModelTests but asserting via the pushed
//  MockUserListView states instead of @Observable properties.
//

import Testing
import SwiftData
@testable import ArchLearning

@MainActor
struct MVPUserListPresenterTests {
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
        let sut = MVPUserListPresenter(service: service, modelContext: context)
        let view = MockUserListView()
        sut.attach(view: view)

        await sut.onAppear()

        #expect(view.latestState == .loaded([TestFixtures.user1]))
        #expect(service.fetchCallCount == 1)
    }

    @Test func onAppearUsesSwiftDataCacheWhenPresent() async throws {
        let service = MockUserService()
        let context = try makeInMemoryContext()
        context.insert(UserRecord(entity: TestFixtures.user2))
        try context.save()

        let sut = MVPUserListPresenter(service: service, modelContext: context)
        let view = MockUserListView()
        sut.attach(view: view)

        await sut.onAppear()

        #expect(view.latestState == .loaded([TestFixtures.user2]))
        #expect(service.fetchCallCount == 0)
    }

    @Test func onRefreshAlwaysFetchesFromServiceAndPersists() async throws {
        let service = MockUserService()
        service.usersToReturn = [TestFixtures.user1, TestFixtures.user2]
        let context = try makeInMemoryContext()
        context.insert(UserRecord(entity: TestFixtures.user1))
        try context.save()

        let sut = MVPUserListPresenter(service: service, modelContext: context)
        let view = MockUserListView()
        sut.attach(view: view)

        await sut.onRefresh()

        #expect(view.latestState == .loaded([TestFixtures.user1, TestFixtures.user2]))
        #expect(view.refreshingValues == [true, false])
        #expect(service.fetchCallCount == 1)

        let descriptor = FetchDescriptor<UserRecord>()
        let saved = try context.fetch(descriptor)
        #expect(saved.count == 2)
    }

    @Test func onAppearPushesErrorStateOnServiceFailure() async throws {
        let service = MockUserService()
        service.errorToThrow = StubError(message: "boom")
        let context = try makeInMemoryContext()
        let sut = MVPUserListPresenter(service: service, modelContext: context)
        let view = MockUserListView()
        sut.attach(view: view)

        await sut.onAppear()

        guard case .error = view.latestState else {
            Issue.record("Expected error state, got \(String(describing: view.latestState))")
            return
        }
    }

    @Test func attachReplaysCurrentStateToLateAttachingView() async throws {
        let service = MockUserService()
        service.usersToReturn = [TestFixtures.user1]
        let context = try makeInMemoryContext()
        let sut = MVPUserListPresenter(service: service, modelContext: context)

        await sut.onAppear()

        let lateView = MockUserListView()
        sut.attach(view: lateView)

        #expect(lateView.displayedStates == [.loaded([TestFixtures.user1])])
    }
}
