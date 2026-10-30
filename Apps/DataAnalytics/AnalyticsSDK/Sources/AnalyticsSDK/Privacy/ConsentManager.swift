import Foundation

/// Synchronously readable consent flag. The flag is checked *inside* the ingress lock when an event is built,
/// and flipped inside the same lock on revocation, so there is no window in which an event can be accepted
/// after `setConsent(.denied)` has returned its first effect.
final class ConsentManager: @unchecked Sendable {
    private let state: Locked<ConsentState>

    init(initial: ConsentState) { state = Locked(initial) }

    var current: ConsentState { state.withLock { $0 } }
    var isGranted: Bool { current == .granted }

    /// Returns the previous state.
    @discardableResult
    func set(_ new: ConsentState) -> ConsentState {
        state.withLock { old in
            defer { old = new }
            return old
        }
    }
}
