import Foundation
import SQLite3

/// SQLite-backed `EventStore`.
///
/// Concurrency: an `actor` serialises all database access. Every method is synchronous inside the actor —
/// no `await` occurs between BEGIN and COMMIT — so actor re-entrancy can never interleave two transactions.
/// The actor protects the *connection*; atomicity of multi-row operations comes from SQLite transactions,
/// not from the actor.
///
/// Durability: WAL + `synchronous=NORMAL`. A committed transaction survives process termination (the dominant
/// iOS failure mode: jetsam, crash, swipe-kill). An OS crash or power loss may lose the last few commits;
/// pass `.full` to trade write latency for that guarantee.
actor SQLiteEventStore: EventStore {
    enum Durability: String { case normal = "NORMAL", full = "FULL" }

    private var db: SQLiteDatabase
    private let url: URL
    private let migrator: DatabaseMigrator
    private let durability: Durability
    private let onRebuild: @Sendable () -> Void

    init(url: URL, migrator: DatabaseMigrator = .standard, durability: Durability = .normal,
         onRebuild: @escaping @Sendable () -> Void = {}) throws {
        self.url = url
        self.migrator = migrator
        self.durability = durability
        self.onRebuild = onRebuild
        self.db = try Self.openPrepared(url: url, migrator: migrator, durability: durability, onRebuild: onRebuild)
    }

    // MARK: Opening, corruption recovery

    private static func openPrepared(url: URL, migrator: DatabaseMigrator, durability: Durability,
                                     onRebuild: @Sendable () -> Void) throws -> SQLiteDatabase {
        let fm = FileManager.default
        let dir = url.deletingLastPathComponent()
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        var mutableDir = dir; try? mutableDir.setResourceValues(values)

        do {
            return try configure(path: url.path, migrator: migrator, durability: durability)
        } catch let e as SQLiteError where e.isCorruption {
            // Quarantine rather than delete: keeps forensic evidence, frees the path for a fresh database.
            quarantine(url)
            onRebuild()
            do { return try configure(path: url.path, migrator: migrator, durability: durability) }
            catch let e as SQLiteError { throw e.analyticsError }
        } catch let e as SQLiteError {
            throw e.analyticsError
        }
    }

    private static func configure(path: String, migrator: DatabaseMigrator, durability: Durability) throws -> SQLiteDatabase {
        let db = try SQLiteDatabase(path: path)
        // Must precede the first table creation; reclaims disk after bulk deletes via incremental_vacuum.
        try db.execute("PRAGMA auto_vacuum = INCREMENTAL")
        try db.execute("PRAGMA journal_mode = WAL")
        try db.execute("PRAGMA synchronous = \(durability.rawValue)")
        try db.execute("PRAGMA journal_size_limit = 4194304")
        try migrator.migrate(db)
        #if os(iOS)
        // Readable after first unlock so uploads can run while the device is locked.
        try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: path)
        #endif
        return db
    }

    private static func quarantine(_ url: URL) {
        let fm = FileManager.default
        let stamp = Int(Date().timeIntervalSince1970)
        try? fm.moveItem(at: url, to: url.appendingPathExtension("corrupt-\(stamp)"))
        for suffix in ["-wal", "-shm"] { try? fm.removeItem(atPath: url.path + suffix) }
    }

    /// Runs `body`; on corruption replaces the database, then reports `.storageCorrupted` (the in-flight
    /// operation is NOT retried silently, and queued events are gone — callers must know).
    private func perform<T>(_ body: (SQLiteDatabase) throws -> T) throws -> T {
        do {
            return try body(db)
        } catch let e as SQLiteError {
            if e.isCorruption { rebuild() }
            throw e.analyticsError
        }
    }

    private func rebuild() {
        db.close()
        Self.quarantine(url)
        onRebuild()
        if let fresh = try? Self.configure(path: url.path, migrator: migrator, durability: durability) { db = fresh }
    }

    // MARK: EventStore

    func insert(_ events: [PersistableEvent], metadata: [MetadataWrite], limits: StorageLimits) throws -> InsertReport {
        try perform { db in
            try db.transaction {
                var outcomes: [InsertOutcome] = []
                outcomes.reserveCapacity(events.count)
                var evicted = 0
                var (count, bytes) = try totals(db)

                for event in events {
                    let size = event.payload.count
                    if count + 1 > limits.maxEvents || bytes + size > limits.maxBytes {
                        switch limits.fullPolicy {
                        case .rejectNew:
                            outcomes.append(.rejectedStorageFull); continue
                        case .dropOldest:
                            let freed = try evictOldest(db,
                                                        needEvents: max(0, count + 1 - limits.maxEvents),
                                                        needBytes: max(0, bytes + size - limits.maxBytes))
                            count -= freed.events; bytes -= freed.bytes; evicted += freed.events
                            if count + 1 > limits.maxEvents || bytes + size > limits.maxBytes {
                                // Everything left is leased (in flight) — refuse rather than evict an upload in progress.
                                outcomes.append(.rejectedStorageFull); continue
                            }
                        }
                    }
                    let changes = try db.run(
                        "INSERT OR IGNORE INTO events (event_id, created_at, payload, payload_bytes) VALUES (?, ?, ?, ?)",
                        [.text(event.eventID), .double(event.createdAt.timeIntervalSince1970), .blob(event.payload), .int(Int64(size))])
                    if changes == 1 { count += 1; bytes += size; outcomes.append(.stored) } else { outcomes.append(.duplicate) }
                }
                try write(metadata, db)
                return InsertReport(outcomes: outcomes, evicted: evicted)
            }
        }
    }

    func leaseBatch(_ request: LeaseRequest) throws -> LeasedBatch? {
        try perform { db in
            try db.transaction {
                let rows = try db.query(
                    """
                    SELECT seq, event_id, created_at, payload, payload_bytes, attempts FROM events
                    WHERE lease_id IS NULL AND next_attempt_at <= ?
                    ORDER BY seq LIMIT ?
                    """,
                    [.double(request.now.timeIntervalSince1970), .int(Int64(min(max(1, request.maxEvents), 500)))]
                ) { r in (seq: r.int(0), event: LeasedEvent(eventID: r.text(1), createdAt: Date(timeIntervalSince1970: r.double(2)),
                                                          payload: r.blob(3), attempts: Int(r.int(5)) + 1)) }

                var selected: [(seq: Int64, event: LeasedEvent)] = []
                var bytes = request.envelopeOverheadBytes
                for row in rows {
                    let add = row.event.payload.count + 1   // +1 for the separating comma
                    // Always take at least one event so an oversized row can never wedge the queue; the server
                    // will answer 413 and it is dropped as permanently rejected.
                    if !selected.isEmpty && bytes + add > request.maxBytes { break }
                    selected.append(row); bytes += add
                }
                guard !selected.isEmpty else { return nil }

                let expires = request.now.addingTimeInterval(request.leaseDuration).timeIntervalSince1970
                for row in selected {
                    try db.run("UPDATE events SET lease_id = ?, lease_expires_at = ?, attempts = attempts + 1 WHERE seq = ?",
                               [.text(request.batchID), .double(expires), .int(row.seq)])
                }
                return LeasedBatch(id: request.batchID, events: selected.map(\.event), totalBytes: bytes)
            }
        }
    }

    func resolve(_ r: BatchResolution) throws -> ResolutionReport {
        let report: ResolutionReport = try perform { db in
            try db.transaction {
                let rows = try db.query("SELECT seq, event_id, attempts FROM events WHERE lease_id = ?", [.text(r.batchID)]) {
                    (seq: $0.int(0), id: $0.text(1), attempts: Int($0.int(2)))
                }
                var report = ResolutionReport()
                for row in rows {
                    if r.deleteEventIDs.contains(row.id) {
                        try db.run("DELETE FROM events WHERE seq = ?", [.int(row.seq)]); report.deleted += 1
                    } else if r.countsAttempt && row.attempts >= r.maxAttempts {
                        try db.run("DELETE FROM events WHERE seq = ?", [.int(row.seq)]); report.droppedMaxAttempts += 1
                    } else {
                        let attempts = r.countsAttempt ? row.attempts : max(0, row.attempts - 1)
                        try db.run("UPDATE events SET lease_id = NULL, lease_expires_at = NULL, next_attempt_at = ?, attempts = ? WHERE seq = ?",
                                   [.double(r.retryAt.timeIntervalSince1970), .int(Int64(attempts)), .int(row.seq)])
                        report.released += 1
                    }
                }
                return report
            }
        }
        reclaimIfWorthwhile(report.deleted + report.droppedMaxAttempts)
        return report
    }

    func recoverExpiredLeases(now: Date) throws -> Int {
        try perform { db in
            // Attempts are NOT refunded: a batch whose upload outcome is unknown consumed an attempt. This is what
            // stops a poison event from crashing the process in a loop forever.
            try db.run("UPDATE events SET lease_id = NULL, lease_expires_at = NULL WHERE lease_id IS NOT NULL AND lease_expires_at <= ?",
                       [.double(now.timeIntervalSince1970)])
        }
    }

    func recoverAllLeases() throws -> Int {
        try perform { db in
            try db.run("UPDATE events SET lease_id = NULL, lease_expires_at = NULL WHERE lease_id IS NOT NULL")
        }
    }

    func purgeExpired(createdBefore: Date) throws -> Int {
        let n = try perform { db in
            try db.run("DELETE FROM events WHERE created_at < ? AND lease_id IS NULL", [.double(createdBefore.timeIntervalSince1970)])
        }
        reclaimIfWorthwhile(n)
        return n
    }

    func stats() throws -> QueueStats {
        try perform { db in
            var stats = try db.query("""
                SELECT COUNT(*), COALESCE(SUM(payload_bytes), 0), MIN(created_at), COALESCE(SUM(lease_id IS NOT NULL), 0) FROM events
                """) { r in
                QueueStats(pendingEvents: Int(r.int(0)), leasedEvents: Int(r.int(3)), payloadBytes: Int(r.int(1)), diskBytes: 0,
                           oldestEventAt: r.isNull(2) ? nil : Date(timeIntervalSince1970: r.double(2)))
            }.first ?? QueueStats()
            let pages = try db.query("PRAGMA page_count") { $0.int(0) }.first ?? 0
            let pageSize = try db.query("PRAGMA page_size") { $0.int(0) }.first ?? 0
            stats.diskBytes = Int(pages * pageSize)
            return stats
        }
    }

    func deleteAllEvents() throws -> Int {
        let n = try perform { db in try db.run("DELETE FROM events") }
        reclaimIfWorthwhile(n)
        return n
    }

    func metadata(_ key: String) throws -> String? {
        try perform { db in try db.query("SELECT value FROM metadata WHERE key = ?", [.text(key)]) { $0.text(0) }.first }
    }

    func setMetadata(_ writes: [MetadataWrite]) throws {
        try perform { db in try db.transaction { try write(writes, db) } }
    }

    func close() { db.close() }

    // MARK: Helpers

    private func totals(_ db: SQLiteDatabase) throws -> (Int, Int) {
        let row = try db.query("SELECT COUNT(*), COALESCE(SUM(payload_bytes), 0) FROM events") { (Int($0.int(0)), Int($0.int(1))) }.first
        return row ?? (0, 0)
    }

    /// Evicts the oldest *unleased* rows until both needs are met. Leased rows are never evicted: an in-flight
    /// upload's outcome must be able to resolve them.
    private func evictOldest(_ db: SQLiteDatabase, needEvents: Int, needBytes: Int) throws -> (events: Int, bytes: Int) {
        let candidates = try db.query("SELECT seq, payload_bytes FROM events WHERE lease_id IS NULL ORDER BY seq LIMIT 500") {
            (seq: $0.int(0), bytes: Int($0.int(1)))
        }
        var events = 0, bytes = 0
        for c in candidates {
            if events >= needEvents && bytes >= needBytes { break }
            try db.run("DELETE FROM events WHERE seq = ?", [.int(c.seq)])
            events += 1; bytes += c.bytes
        }
        return (events, bytes)
    }

    private func write(_ writes: [MetadataWrite], _ db: SQLiteDatabase) throws {
        for w in writes {
            if let value = w.value {
                try db.run("INSERT INTO metadata (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value",
                           [.text(w.key), .text(value)])
            } else {
                try db.run("DELETE FROM metadata WHERE key = ?", [.text(w.key)])
            }
        }
    }

    private func reclaimIfWorthwhile(_ deletedRows: Int) {
        if deletedRows >= 50 { try? db.execute("PRAGMA incremental_vacuum(256)") }
    }
}
