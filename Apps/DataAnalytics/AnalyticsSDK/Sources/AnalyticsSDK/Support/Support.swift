import Foundation

/// Small lock-protected box. Used for state that must be readable from synchronous, nonisolated call sites
/// (e.g. `enqueue`) where an actor hop is impossible. Critical sections must stay tiny and never `await`.
final class Locked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) { self.value = value }

    func withLock<R>(_ body: (inout Value) throws -> R) rethrows -> R {
        lock.lock()
        defer { lock.unlock() }
        return try body(&value)
    }
}

/// Wall-clock and sleep abstraction. Injected so retry/backoff/session tests never wait in real time.
protocol AnalyticsClock: Sendable {
    func now() -> Date
    func sleep(for interval: TimeInterval) async throws
}

struct SystemClock: AnalyticsClock {
    func now() -> Date { Date() }
    func sleep(for interval: TimeInterval) async throws {
        guard interval > 0 else { return }
        try await Task.sleep(nanoseconds: UInt64(min(interval, 86_400) * 1_000_000_000))
    }
}

enum AnalyticsSDKInfo {
    static let version = "1.0.0"
    /// Version of the on-disk/wire event schema produced by this SDK build.
    static let eventSchemaVersion = 1
}

/// Keys of the small key/value table stored beside the queue (same database, same transactions).
enum MetadataKey {
    static let anonymousID = "identity.anonymous_id"
    static let userID = "identity.user_id"
    static let consent = "consent.state"
    static let session = "session.state"
}

struct MetadataWrite: Sendable, Equatable {
    var key: String
    /// `nil` deletes the key.
    var value: String?
}
