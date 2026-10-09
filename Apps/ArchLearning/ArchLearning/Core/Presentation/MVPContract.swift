//
//  MVPContract.swift
//  ArchLearning
//
//  Shared MVP contract reused by both the "MVP Only" and "Clean + MVP"
//  demo screens. Unlike MVVM (where the ViewModel exposes @Observable
//  state the View reactively *pulls* from), MVP is a *push* pattern: the
//  Presenter knows about a passive `UserListViewProtocol` and explicitly
//  tells it what to render. Presenters here have zero SwiftUI/Observation
//  imports — they could drive a UIKit view controller just as easily.
//

import Foundation
import Combine

enum UserListViewState: Equatable {
    case idle
    case loading
    case loaded([UserEntity])
    case error(String)
}

/// The passive view contract a Presenter pushes state to. Conforming types
/// (SwiftUI state stores, UIKit view controllers, test doubles) decide how
/// to render/record the pushed state.
@MainActor
protocol UserListViewProtocol: AnyObject {
    func display(state: UserListViewState)
    func setRefreshing(_ isRefreshing: Bool)
}

/// Bridges the imperative MVP `display`/`setRefreshing` calls into
/// SwiftUI-observable `@Published` properties so a SwiftUI `View` can bind
/// to it with `@StateObject`. This adapter is the only SwiftUI-aware piece
/// in the MVP stack; the Presenters themselves stay framework-agnostic.
@MainActor
final class MVPViewStateStore: ObservableObject, UserListViewProtocol {
    @Published private(set) var state: UserListViewState = .idle
    @Published private(set) var isRefreshing = false

    func display(state: UserListViewState) {
        self.state = state
    }

    func setRefreshing(_ isRefreshing: Bool) {
        self.isRefreshing = isRefreshing
    }
}
