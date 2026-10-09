//
//  CleanUserListPresenterTests.swift
//  ArchLearningTests
//
//  Verifies the Clean + MVP presenter's state transitions, driven purely
//  through the FetchUsersUseCaseProtocol mock and a MockUserListView — no
//  networking, SwiftData, or SwiftUI involved.
//

import Testing
@testable import ArchLearning

@MainActor
struct CleanUserListPresenterTests {
    @Test func attachReplaysCurrentStateImmediately() async {
        let useCase = MockFetchUsersUseCase()
        let sut = CleanUserListPresenter(fetchUsersUseCase: useCase)
        let view = MockUserListView()

        sut.attach(view: view)

        #expect(view.displayedStates == [.idle])
    }

    @Test func onAppearPushesLoadingThenLoadedStates() async {
        let useCase = MockFetchUsersUseCase()
        useCase.usersToReturn = [TestFixtures.user1, TestFixtures.user2]
        let sut = CleanUserListPresenter(fetchUsersUseCase: useCase)
        let view = MockUserListView()
        sut.attach(view: view)

        await sut.onAppear()

        #expect(view.displayedStates == [.idle, .loading, .loaded([TestFixtures.user1, TestFixtures.user2])])
        #expect(useCase.executeCalls == [false])
    }

    @Test func onAppearPushesErrorStateOnFailure() async {
        let useCase = MockFetchUsersUseCase()
        useCase.errorToThrow = StubError(message: "boom")
        let sut = CleanUserListPresenter(fetchUsersUseCase: useCase)
        let view = MockUserListView()
        sut.attach(view: view)

        await sut.onAppear()

        guard case .error = view.latestState else {
            Issue.record("Expected error state, got \(String(describing: view.latestState))")
            return
        }
    }

    @Test func onAppearIsIdempotentAfterFirstLoad() async {
        let useCase = MockFetchUsersUseCase()
        useCase.usersToReturn = [TestFixtures.user1]
        let sut = CleanUserListPresenter(fetchUsersUseCase: useCase)
        let view = MockUserListView()
        sut.attach(view: view)

        await sut.onAppear()
        await sut.onAppear()

        #expect(useCase.executeCalls == [false])
    }

    @Test func onRefreshForcesRemoteFetchAndTogglesRefreshingAroundCall() async {
        let useCase = MockFetchUsersUseCase()
        useCase.usersToReturn = [TestFixtures.user2]
        let sut = CleanUserListPresenter(fetchUsersUseCase: useCase)
        let view = MockUserListView()
        sut.attach(view: view)

        await sut.onRefresh()

        #expect(useCase.executeCalls == [true])
        #expect(view.refreshingValues == [true, false])
        #expect(view.latestState == .loaded([TestFixtures.user2]))
    }
}
