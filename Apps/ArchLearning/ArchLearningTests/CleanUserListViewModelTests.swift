//
//  CleanUserListViewModelTests.swift
//  ArchLearningTests
//
//  Verifies the Clean + MVVM view model's state transitions, driven
//  purely through the FetchUsersUseCaseProtocol mock (no networking or
//  SwiftData involved).
//

import Testing
@testable import ArchLearning

@MainActor
struct CleanUserListViewModelTests {
    @Test func onAppearLoadsUsersSuccessfully() async {
        let useCase = MockFetchUsersUseCase()
        useCase.usersToReturn = [TestFixtures.user1, TestFixtures.user2]
        let sut = CleanUserListViewModel(fetchUsersUseCase: useCase)

        await sut.onAppear()

        #expect(sut.state == .loaded([TestFixtures.user1, TestFixtures.user2]))
        #expect(useCase.executeCalls == [false])
    }

    @Test func onAppearSetsErrorStateOnFailure() async {
        let useCase = MockFetchUsersUseCase()
        useCase.errorToThrow = StubError(message: "boom")
        let sut = CleanUserListViewModel(fetchUsersUseCase: useCase)

        await sut.onAppear()

        guard case .error = sut.state else {
            Issue.record("Expected error state, got \(sut.state)")
            return
        }
    }

    @Test func onAppearIsIdempotentAfterFirstLoad() async {
        let useCase = MockFetchUsersUseCase()
        useCase.usersToReturn = [TestFixtures.user1]
        let sut = CleanUserListViewModel(fetchUsersUseCase: useCase)

        await sut.onAppear()
        await sut.onAppear()

        #expect(useCase.executeCalls == [false])
    }

    @Test func refreshForcesRemoteFetchAndTogglesIsRefreshing() async {
        let useCase = MockFetchUsersUseCase()
        useCase.usersToReturn = [TestFixtures.user2]
        let sut = CleanUserListViewModel(fetchUsersUseCase: useCase)

        await sut.refresh()

        #expect(sut.state == .loaded([TestFixtures.user2]))
        #expect(useCase.executeCalls == [true])
        #expect(sut.isRefreshing == false)
    }
}
