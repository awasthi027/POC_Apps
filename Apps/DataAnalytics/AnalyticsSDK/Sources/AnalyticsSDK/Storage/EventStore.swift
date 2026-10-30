import Foundation

/// A fully processed event ready for durable storage. `payload` is the exact JSON that will be uploaded.
struct PersistableEvent: Sendable, Equatable {
    var eventID: String
    var createdAt: Date
    var payload: Data
}

struct LeasedEvent: Sendable, Equatable {
    var eventID: String
    var createdAt: Date
    var payload: Data
    /// Attempts including the current one.
    var attempts: Int
}

struct StorageLimits: Sendable, Equatable {
    var maxEvents: Int
    var maxBytes: Int
    var fullPolicy: StorageFullPolicy
}

enum InsertOutcome: Sendable, Equatable {
    case stored
    /// Same event ID already queued. Treated as success: IDs are stable, so this is an idempotent re-insert.
    case duplicate
    case rejectedStorageFull
}

struct InsertReport: Sendable, Equatable {
    var outcomes: [InsertOutcome]
    var evicted: Int
}

struct LeaseRequest: Sendable {
    var batchID: String
    var maxEvents: Int
    var maxBytes: Int
    /// Bytes of the request envelope around the events; counted against `maxBytes`.
    var envelopeOverheadBytes: Int
    var now: Date
    var leaseDuration: TimeInterval
}

struct LeasedBatch: Sendable, Equatable {
    var id: String
    var events: [LeasedEvent]
    var totalBytes: Int
}

struct BatchResolution: Sendable {
    var batchID: String
    /// Events to delete: acknowledged, duplicate, or permanently rejected by the server.
    var deleteEventIDs: Set<String>
    /// When remaining events of the batch become eligible again.
    var retryAt: Date
    /// `false` refunds the attempt consumed by leasing (offline, 429, auth pause, shrink-and-retry).
    var countsAttempt: Bool
    var maxAttempts: Int
}

struct ResolutionReport: Sendable, Equatable {
    var deleted = 0
    /// Retry budget exhausted → deleted and reported.
    var droppedMaxAttempts = 0
    var released = 0
}

struct QueueStats: Sendable, Equatable {
    var pendingEvents = 0
    var leasedEvents = 0
    var payloadBytes = 0
    var diskBytes = 0
    var oldestEventAt: Date?
}

/// Durable queue. Every method is atomic: it either commits fully or has no effect.
///
/// Implementations must guarantee that `insert` returning `.stored` means the transaction committed, and that
/// `leaseBatch` never hands the same event to two callers (so a future multi-worker design stays correct).
protocol EventStore: Sendable {
    /// Inserts events and applies metadata writes in ONE transaction (identity/session state commits
    /// atomically with the events that reference it). `events` may be empty for a metadata-only commit.
    func insert(_ events: [PersistableEvent], metadata: [MetadataWrite], limits: StorageLimits) async throws -> InsertReport
    func leaseBatch(_ request: LeaseRequest) async throws -> LeasedBatch?
    func resolve(_ resolution: BatchResolution) async throws -> ResolutionReport
    func recoverExpiredLeases(now: Date) async throws -> Int
    /// Startup recovery: the previous process is gone, so every lease is abandoned.
    func recoverAllLeases() async throws -> Int
    func purgeExpired(createdBefore: Date) async throws -> Int
    func stats() async throws -> QueueStats
    func deleteAllEvents() async throws -> Int
    func metadata(_ key: String) async throws -> String?
    func setMetadata(_ writes: [MetadataWrite]) async throws
    func close() async
}
