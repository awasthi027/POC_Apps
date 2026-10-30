import Foundation
import Testing
@testable import AnalyticsSDK

@Suite final class EventStoreTests {
    private let harness = Harness()
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    deinit { harness.cleanUp() }

    private func lease(_ store: SQLiteEventStore, id: String = "b1", events: Int = 100, bytes: Int = 1_000_000, now: Date? = nil) async throws -> LeasedBatch? {
        try await store.leaseBatch(LeaseRequest(batchID: id, maxEvents: events, maxBytes: bytes, envelopeOverheadBytes: 0,
                                                now: now ?? t0, leaseDuration: 300))
    }

    @Test func committedEventsSurviveReopen() async throws {
        let store = try harness.openStore()
        let report = try await store.insert([makeEvent("a"), makeEvent("b")], metadata: [MetadataWrite(key: "k", value: "v")], limits: roomyLimits)
        #expect(report.outcomes == [.stored, .stored])
        await store.close()

        let reopened = try harness.openStore()
        let stats = try await reopened.stats()
        #expect(stats.pendingEvents == 2)
        let metadata = try await reopened.metadata("k")
        #expect(metadata == "v")
    }

    @Test func transactionRollsBackEverythingOnFailure() throws {
        let db = try SQLiteDatabase(path: harness.directory.appendingPathComponent("raw.sqlite").path)
        try db.execute("CREATE TABLE t (id TEXT PRIMARY KEY)")
        #expect(throws: SQLiteError.self) {
            try db.transaction {
                try db.run("INSERT INTO t VALUES ('a')")
                try db.run("INSERT INTO t VALUES ('b')")
                try db.run("INSERT INTO t VALUES ('a')")    // PK violation → whole transaction must vanish
            }
        }
        #expect(try db.query("SELECT COUNT(*) FROM t") { $0.int(0) } == [0])
    }

    @Test func duplicateEventIDIsIdempotentInsert() async throws {
        let store = try harness.openStore()
        _ = try await store.insert([makeEvent("a")], metadata: [], limits: roomyLimits)
        let again = try await store.insert([makeEvent("a")], metadata: [], limits: roomyLimits)
        #expect(again.outcomes == [.duplicate])
        let pending = try await store.stats().pendingEvents
        #expect(pending == 1)
    }

    @Test func batchHonoursEventCountAndByteLimits() async throws {
        let store = try harness.openStore()
        _ = try await store.insert((0..<10).map { makeEvent("e\($0)", bytes: 100) }, metadata: [], limits: roomyLimits)

        let byCount = try await lease(store, id: "c", events: 4)
        #expect(byCount?.events.count == 4)
        // 250 byte cap, 100 bytes + 1 comma each, 50 envelope → 1 + 2*101 = 252 > 250 → only 1... use 360: 50+101*3=353 ≤ 360
        let byBytes = try await store.leaseBatch(LeaseRequest(batchID: "d", maxEvents: 100, maxBytes: 360, envelopeOverheadBytes: 50, now: t0, leaseDuration: 300))
        #expect(byBytes?.events.count == 3)
        #expect(byBytes?.totalBytes ?? .max <= 360)
    }

    @Test func oversizedSingleEventStillLeasesSoQueueCannotWedge() async throws {
        let store = try harness.openStore()
        _ = try await store.insert([makeEvent("big", bytes: 5_000)], metadata: [], limits: roomyLimits)
        let batch = try await lease(store, bytes: 1_000)
        #expect(batch?.events.count == 1)
    }

    @Test func concurrentLeasesNeverOverlap() async throws {
        let store = try harness.openStore()
        _ = try await store.insert((0..<200).map { makeEvent("e\($0)") }, metadata: [], limits: roomyLimits)
        let batches = try await withThrowingTaskGroup(of: LeasedBatch?.self) { group in
            for i in 0..<16 { group.addTask { try await self.lease(store, id: "batch-\(i)", events: 20) } }
            var all: [LeasedBatch] = []
            for try await b in group { if let b { all.append(b) } }
            return all
        }
        let ids = batches.flatMap { $0.events.map(\.eventID) }
        #expect(ids.count == Set(ids).count, "an event was leased to two batches")
        #expect(ids.count == 200)
    }

    @Test func leasedEventsAreInvisibleUntilResolvedOrRecovered() async throws {
        let store = try harness.openStore()
        _ = try await store.insert([makeEvent("a"), makeEvent("b")], metadata: [], limits: roomyLimits)
        let first = try await lease(store, id: "one")
        #expect(first?.events.count == 2)
        let second = try await lease(store, id: "two")
        #expect(second == nil)

        let early = try await store.recoverExpiredLeases(now: t0.addingTimeInterval(299))
        #expect(early == 0)
        let recovered = try await store.recoverExpiredLeases(now: t0.addingTimeInterval(301))
        #expect(recovered == 2)
        let again = try await lease(store, id: "three", now: t0.addingTimeInterval(301))
        #expect(again?.events.count == 2)
        #expect(again?.events.map(\.attempts) == [2, 2], "an abandoned attempt still counts: poison events cannot crash-loop forever")
    }

    @Test func recoverAllLeasesAfterProcessDeath() async throws {
        let store = try harness.openStore()
        _ = try await store.insert([makeEvent("a")], metadata: [], limits: roomyLimits)
        _ = try await lease(store)
        await store.close()                                     // "process killed" with the lease outstanding

        let next = try harness.openStore()
        let recovered = try await next.recoverAllLeases()
        #expect(recovered == 1)
        let batch = try await lease(next, id: "again")
        #expect(batch?.events.map(\.eventID) == ["a"])
    }

    @Test func resolveDeletesConfirmedAndReleasesTheRest() async throws {
        let store = try harness.openStore()
        _ = try await store.insert((0..<4).map { makeEvent("e\($0)") }, metadata: [], limits: roomyLimits)
        _ = try await lease(store, id: "b")
        let report = try await store.resolve(BatchResolution(batchID: "b", deleteEventIDs: ["e0", "e1"], retryAt: t0.addingTimeInterval(60),
                                                             countsAttempt: true, maxAttempts: 5))
        #expect(report == ResolutionReport(deleted: 2, droppedMaxAttempts: 0, released: 2))

        let tooSoon = try await lease(store, id: "x", now: t0.addingTimeInterval(59))
        #expect(tooSoon == nil, "released events honour their retry time")
        let later = try await lease(store, id: "y", now: t0.addingTimeInterval(61))
        #expect(Set(later?.events.map(\.eventID) ?? []) == ["e2", "e3"])
    }

    @Test func attemptBudgetDropsPoisonAndRefundsUncountedFailures() async throws {
        let store = try harness.openStore()
        _ = try await store.insert([makeEvent("a")], metadata: [], limits: roomyLimits)
        for i in 1...3 {
            _ = try await lease(store, id: "b\(i)", now: t0.addingTimeInterval(Double(i)))
            let r = try await store.resolve(BatchResolution(batchID: "b\(i)", deleteEventIDs: [], retryAt: t0, countsAttempt: true, maxAttempts: 3))
            #expect(r.droppedMaxAttempts == (i == 3 ? 1 : 0))
        }
        let leftover = try await store.stats().pendingEvents
        #expect(leftover == 0)

        _ = try await store.insert([makeEvent("b")], metadata: [], limits: roomyLimits)
        for i in 1...10 {                                       // offline / 429 style failures never exhaust the budget
            _ = try await lease(store, id: "o\(i)")
            _ = try await store.resolve(BatchResolution(batchID: "o\(i)", deleteEventIDs: [], retryAt: t0, countsAttempt: false, maxAttempts: 3))
        }
        let survivor = try await store.stats().pendingEvents
        #expect(survivor == 1)
    }

    @Test func dropOldestEvictsUnleasedButNeverLeased() async throws {
        let store = try harness.openStore()
        let limits = StorageLimits(maxEvents: 3, maxBytes: 1_000_000, fullPolicy: .dropOldest)
        _ = try await store.insert((0..<3).map { makeEvent("e\($0)") }, metadata: [], limits: limits)
        let report = try await store.insert([makeEvent("e3")], metadata: [], limits: limits)
        #expect(report.outcomes == [.stored])
        #expect(report.evicted == 1, "oldest (e0) evicted, and reported")

        _ = try await lease(store, id: "all")                    // everything now leased / in flight
        let blocked = try await store.insert([makeEvent("e4")], metadata: [], limits: limits)
        #expect(blocked.outcomes == [.rejectedStorageFull], "never evict an in-flight upload; refuse loudly instead")
    }

    @Test func rejectNewKeepsQueuedEvents() async throws {
        let store = try harness.openStore()
        let limits = StorageLimits(maxEvents: 2, maxBytes: 1_000_000, fullPolicy: .rejectNew)
        let report = try await store.insert((0..<3).map { makeEvent("e\($0)") }, metadata: [], limits: limits)
        #expect(report.outcomes == [.stored, .stored, .rejectedStorageFull])
    }

    @Test func byteLimitIsEnforcedIndependentlyOfCount() async throws {
        let store = try harness.openStore()
        let limits = StorageLimits(maxEvents: 1000, maxBytes: 250, fullPolicy: .rejectNew)
        let report = try await store.insert((0..<5).map { makeEvent("e\($0)", bytes: 100) }, metadata: [], limits: limits)
        #expect(report.outcomes.filter { $0 == .stored }.count == 2)
    }

    @Test func retentionPurgesOldUnleasedEvents() async throws {
        let store = try harness.openStore()
        _ = try await store.insert([makeEvent("old", at: t0.addingTimeInterval(-1000)), makeEvent("new", at: t0)], metadata: [], limits: roomyLimits)
        let purged = try await store.purgeExpired(createdBefore: t0.addingTimeInterval(-500))
        #expect(purged == 1)
    }

    @Test func migrationsRunOnceInOrderAndNewerDatabasesAreRefused() async throws {
        let v2 = DatabaseMigrator(migrations: DatabaseMigrator.standard.migrations + [
            DatabaseMigration(version: 2, statements: ["ALTER TABLE events ADD COLUMN last_error TEXT"])])
        let path = harness.directory.appendingPathComponent("m.sqlite")
        let store = try SQLiteEventStore(url: path, migrator: v2)
        _ = try await store.insert([makeEvent("a")], metadata: [], limits: roomyLimits)
        await store.close()

        let reopened = try SQLiteEventStore(url: path, migrator: v2)                    // no re-run, data intact
        let count = try await reopened.stats().pendingEvents
        #expect(count == 1)
        await reopened.close()

        #expect(throws: AnalyticsError.incompatibleDatabase(found: 2, supported: 1)) {   // "downgrade"
            try SQLiteEventStore(url: path, migrator: .standard)
        }
    }

    @Test func corruptDatabaseIsQuarantinedAndReplaced() async throws {
        try Data("this is not a sqlite file, not even close, padding padding padding".utf8).write(to: harness.databaseURL)
        let rebuilt = Locked(0)
        let store = try SQLiteEventStore(url: harness.databaseURL, onRebuild: { rebuilt.withLock { $0 += 1 } })
        #expect(rebuilt.withLock { $0 } == 1, "caller is told; queued events are gone, not silently ignored")
        let report = try await store.insert([makeEvent("a")], metadata: [], limits: roomyLimits)
        #expect(report.outcomes == [.stored])
        let siblings = try FileManager.default.contentsOfDirectory(atPath: harness.directory.path)
        #expect(siblings.contains { $0.contains("corrupt-") })
    }

    @Test func metadataCommitsAtomicallyWithEvents() async throws {
        let store = try harness.openStore()
        let limits = StorageLimits(maxEvents: 10, maxBytes: 1_000_000, fullPolicy: .rejectNew)
        _ = try await store.insert([makeEvent("a")], metadata: [MetadataWrite(key: "session.state", value: "S1")], limits: limits)
        let value = try await store.metadata("session.state")
        #expect(value == "S1")
        try await store.setMetadata([MetadataWrite(key: "session.state", value: nil)])
        let removed = try await store.metadata("session.state")
        #expect(removed == nil)
    }
}
