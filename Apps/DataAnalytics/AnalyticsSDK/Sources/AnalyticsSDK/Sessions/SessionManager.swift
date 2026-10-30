import Foundation

/// Inactivity-based sessions with crash recovery.
///
/// State is held in memory and persisted by piggy-backing on the event commit transaction (`drainDirty`), so
/// the persisted `lastActivityAt` is never ahead of the events that justify it. After a restart:
///  - within `timeout` of the last activity → the session resumes with the same ID;
///  - otherwise the old session is closed as `interrupted`, stamped at its last known activity time, and a new
///    session starts on the next event.
final class SessionManager: @unchecked Sendable {
    struct State: Codable, Equatable, Sendable {
        var id: String
        var startedAt: Date
        var lastActivityAt: Date
    }

    enum EndReason: String, Sendable { case timeout, interrupted, explicit, identityChanged = "identity_changed" }

    enum Transition: Equatable, Sendable {
        case ended(State, EndReason, at: Date)
        case started(State)
    }

    private struct Inner {
        var current: State?
        var pending: [Transition] = []
        var dirty = false
    }

    private let inner = Locked(Inner())
    private let timeout: TimeInterval
    private let makeID: @Sendable () -> String

    init(timeout: TimeInterval, makeID: @escaping @Sendable () -> String) {
        self.timeout = timeout
        self.makeID = makeID
    }

    func restore(_ persisted: State?, now: Date) {
        inner.withLock { s in
            guard let persisted else { return }
            if now.timeIntervalSince(persisted.lastActivityAt) > timeout {
                s.pending.append(.ended(persisted, .interrupted, at: persisted.lastActivityAt))
                s.dirty = true
            } else {
                s.current = persisted
            }
        }
    }

    /// Records activity. Returns the session the activity belongs to plus any transitions (ordered) that must be
    /// emitted *before* the activity's own event.
    func touch(now: Date) -> (sessionID: String, transitions: [Transition]) {
        inner.withLock { s in
            var transitions = s.pending
            s.pending = []
            if let cur = s.current, now.timeIntervalSince(cur.lastActivityAt) > timeout {
                transitions.append(.ended(cur, .timeout, at: cur.lastActivityAt))
                s.current = nil
            }
            if s.current == nil {
                let fresh = State(id: makeID(), startedAt: now, lastActivityAt: now)
                s.current = fresh
                transitions.append(.started(fresh))
            } else if var cur = s.current {
                cur.lastActivityAt = max(now, cur.lastActivityAt)
                s.current = cur
            }
            s.dirty = true
            return (s.current?.id ?? "", transitions)
        }
    }

    /// Ends the current session (explicit API, logout, account switch). The next `touch` starts a new one.
    func end(now: Date, reason: EndReason) -> [Transition] {
        inner.withLock { s in
            var transitions = s.pending
            s.pending = []
            if let cur = s.current {
                transitions.append(.ended(cur, reason, at: now))
                s.current = nil
            }
            s.dirty = true
            return transitions
        }
    }

    var currentSessionID: String? { inner.withLock { $0.current?.id } }

    func drainDirty() -> MetadataWrite? {
        inner.withLock { s in
            guard s.dirty else { return nil }
            s.dirty = false
            let json = s.current.flatMap { try? JSONEncoder().encode($0) }.flatMap { String(data: $0, encoding: .utf8) }
            return MetadataWrite(key: MetadataKey.session, value: json)
        }
    }

    func markDirty() { inner.withLock { $0.dirty = true } }
}
