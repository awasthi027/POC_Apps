import Foundation

/// Holds the current anonymous/user identity. Events capture a snapshot at creation; changing identity never
/// rewrites events that are already queued (they keep the identity they were created under).
final class IdentityManager: @unchecked Sendable {
    private struct State {
        var anonymousID: String
        var userID: String?
        var dirty: Bool
    }

    private let state: Locked<State>

    init(anonymousID: String, userID: String?, needsPersist: Bool) {
        state = Locked(State(anonymousID: anonymousID, userID: userID, dirty: needsPersist))
    }

    func snapshot() -> IdentitySnapshot {
        state.withLock { IdentitySnapshot(anonymousID: $0.anonymousID, userID: $0.userID) }
    }

    func setUser(_ userID: String) {
        state.withLock { $0.userID = userID; $0.dirty = true }
    }

    /// Logout / account switch: forget the user and start a fresh anonymous identity so the next person on
    /// this device is not linked to the previous one.
    func reset(newAnonymousID: String) {
        state.withLock { $0.userID = nil; $0.anonymousID = newAnonymousID; $0.dirty = true }
    }

    func drainDirty() -> [MetadataWrite] {
        state.withLock { s in
            guard s.dirty else { return [] }
            s.dirty = false
            return [MetadataWrite(key: MetadataKey.anonymousID, value: s.anonymousID),
                    MetadataWrite(key: MetadataKey.userID, value: s.userID)]
        }
    }

    func markDirty() { state.withLock { $0.dirty = true } }
}
