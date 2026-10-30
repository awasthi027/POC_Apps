import Foundation
import Testing
@testable import AnalyticsSDK

/// Drives the real SDK + real SQLite store with a fake transport and a manual clock.
@Suite final class UploadCoordinatorTests {
    private let h = Harness()

    deinit { h.cleanUp() }

    private func trackMany(_ sdk: AnalyticsSDK, _ n: Int) async throws {
        for i in 0..<n { try await sdk.track("evt", properties: ["i": .int(i)]) }
    }

    private func pending(_ sdk: AnalyticsSDK) async -> Int { await sdk.diagnostics().pendingEvents }

    // MARK: Acknowledgment semantics

    @Test func acknowledgedEventsAreDeletedAndNothingElse() async throws {
        let sdk = try await h.makeSDK()
        try await trackMany(sdk, 3)                            // + $session_start
        let report = try await sdk.flush()
        #expect(report.status == .completed)
        #expect(report.remainingEvents == 0)
        #expect(h.transport.requests.flatMap(\.events).count == 4)
        await sdk.shutdown()
    }

    @Test func partialAckDeletesOnlyConfirmedEventsAndRetriesTheRestWithSameIDs() async throws {
        let sdk = try await h.makeSDK()
        try await trackMany(sdk, 4)
        let firstBatchIDs = Locked<[String]>([])
        h.transport.setHandler { request in
            let ids = request.events.map(\.eventID)
            if firstBatchIDs.withLock({ $0.isEmpty }) {
                firstBatchIDs.withLock { $0 = ids }
                return .acknowledged(UploadAcknowledgment(batchID: request.batchID, accepted: Array(ids.prefix(2))))
            }
            return FakeTransport.ackAll(request)
        }
        let report = try await sdk.flush()
        #expect(report.acknowledgedEvents == 2)
        let remaining = await pending(sdk)
        #expect(remaining == 3, "5 events sent, 2 confirmed, 3 retained")
        #expect(report.status == .completed, "progress was made; the 3 retained events just aren't eligible yet")
        #expect(report.remainingEvents == 3)

        h.clock.advance(by: 60)                                  // wakes the coordinator without any interval tick
        await eventually { self.h.transport.requests.count == 2 }
        _ = try await sdk.flush()
        let retried = h.transport.requests.last!.events.map(\.eventID)
        #expect(Set(retried) == Set(firstBatchIDs.withLock { $0 }.dropFirst(2)), "same IDs on retry")
        let left = await pending(sdk)
        #expect(left == 0)
        await sdk.shutdown()
    }

    /// The critical distributed-systems scenario: server processed the batch, the response was lost.
    @Test func lostAcknowledgmentThenRetryReusesIDsAndDuplicateAckClearsQueue() async throws {
        let sdk = try await h.makeSDK()
        try await trackMany(sdk, 3)
        let serverStore = Locked<Set<String>>([])               // the "server" durably stored events, but the reply never arrives
        h.transport.setHandler { request in
            serverStore.withLock { $0.formUnion(request.events.map(\.eventID)) }
            return .network(.timeout)
        }
        let first = try await sdk.flush()
        if case .backingOff = first.status {} else { Issue.record("\(first.status)") }
        let queuedAfterLoss = await pending(sdk)
        #expect(queuedAfterLoss == 4, "unconfirmed events must stay queued")
        let firstPayloads = h.transport.requests[0].events.map(\.payload)

        h.transport.setHandler { request in                     // server now recognises every ID as already processed
            let ids = request.events.map(\.eventID)
            let dupes = ids.filter { id in serverStore.withLock { $0.contains(id) } }
            return .acknowledged(UploadAcknowledgment(batchID: request.batchID, duplicates: dupes))
        }
        h.clock.advance(by: 60)
        let second = try await sdk.flush()
        #expect(second.status == .completed)
        #expect(h.transport.requests.last!.events.map(\.payload) == firstPayloads, "byte-identical payloads, identical IDs")
        let left = await pending(sdk)
        #expect(left == 0, "duplicate == already processed == safe to delete")
        await sdk.shutdown()
    }

    @Test func malformedOrNonDurableSuccessNeverDeletes() async throws {
        let sdk = try await h.makeSDK()
        try await trackMany(sdk, 2)
        h.transport.setHandler { _ in .malformedAcknowledgment }
        _ = try await sdk.flush()
        let left = await pending(sdk)
        #expect(left == 3)

        // Classification of real HTTP responses
        let req = UploadRequest(batchID: "b", projectID: "p", sdkVersion: "1", sentAt: Date(), events: [])
        #expect(URLSessionTransport.classify(status: 202, data: Data(), retryAfter: nil, request: req) == .malformedAcknowledgment)
        #expect(URLSessionTransport.classify(status: 204, data: Data(), retryAfter: nil, request: req) == .malformedAcknowledgment)
        #expect(URLSessionTransport.classify(status: 200, data: Data("{nope".utf8), retryAfter: nil, request: req) == .malformedAcknowledgment)
        let wrongBatch = Data(#"{"batch_id":"other","accepted_event_ids":["x"]}"#.utf8)
        #expect(URLSessionTransport.classify(status: 200, data: wrongBatch, retryAfter: nil, request: req) == .malformedAcknowledgment)
        let good = Data(#"{"batch_id":"b","accepted_event_ids":["x"]}"#.utf8)
        #expect(URLSessionTransport.classify(status: 200, data: good, retryAfter: nil, request: req) == .acknowledged(UploadAcknowledgment(batchID: "b", accepted: ["x"])))
        await sdk.shutdown()
    }

    @Test func acknowledgmentResolutionRules() {
        let ack = UploadAcknowledgment(batchID: "b", accepted: ["a", "x"], duplicates: ["d", "x"],
                                       rejected: [.init(eventID: "p", reason: "invalid_schema", retryable: false),
                                                  .init(eventID: "r", reason: "busy", retryable: true)])
        let res = ack.resolve(sentEventIDs: ["a", "d", "p", "r", "x", "unacked"])
        #expect(res.confirmed == ["a", "d"])
        #expect(res.permanentlyRejected == ["p": "invalid_schema"])
        #expect(res.retain == ["r", "x", "unacked"], "retryable, contradictory (x in two lists) and unlisted events are kept")
        #expect(res.deletable == ["a", "d", "p"])
    }

    @Test func permanentRejectionIsDroppedAndCountedRetryableIsKept() async throws {
        let sdk = try await h.makeSDK()
        try await trackMany(sdk, 2)
        h.transport.setHandler { request in
            let ids = request.events.map(\.eventID)
            return .acknowledged(UploadAcknowledgment(batchID: request.batchID, accepted: [ids[0]],
                                                      rejected: [.init(eventID: ids[1], reason: "invalid_schema", retryable: false),
                                                                 .init(eventID: ids[2], reason: "overloaded", retryable: true)]))
        }
        _ = try await sdk.flush()
        let diag = await sdk.diagnostics()
        #expect(diag.dropped[.permanentlyRejected] == 1)
        #expect(diag.pendingEvents == 1)
        await sdk.shutdown()
    }

    // MARK: Failure classes

    @Test func rateLimitHonoursRetryAfterWithoutConsumingAttempts() async throws {
        let sdk = try await h.makeSDK()
        try await trackMany(sdk, 1)
        h.transport.setHandler { _ in .rateLimited(retryAfter: 120) }
        let first = try await sdk.flush()
        guard case .backingOff(let until) = first.status else { return fail("\(first.status)") }
        #expect(abs((until.timeIntervalSince(h.clock.now())) - (120)) <= 0.5)

        let before = h.transport.requests.count
        h.clock.advance(by: 60)
        _ = try await sdk.flush()
        #expect(h.transport.requests.count == before, "no request before Retry-After elapses")

        h.transport.setHandler { FakeTransport.ackAll($0) }
        h.clock.advance(by: 61)
        let done = try await sdk.flush()
        #expect(done.status == .completed)
        await sdk.shutdown()
    }

    @Test func serverErrorsBackOffExponentiallyAndAreCappedByAttemptBudget() async throws {
        let sdk = try await h.makeSDK { $0.upload.retry.maxAttempts = 3 }
        try await trackMany(sdk, 1)                             // 2 events
        h.transport.setHandler { _ in .serverError(status: 503, retryAfter: nil) }

        _ = try await sdk.flush()                               // failure 1 → delay 3.75s (jitter 0.5 of 5s ceiling… 2.5+1.25)
        var previous = h.transport.requests.count
        h.clock.advance(by: 2)
        _ = try await sdk.flush()
        #expect(h.transport.requests.count == previous, "still inside backoff window")

        h.clock.advance(by: 5)
        _ = try await sdk.flush()                               // failure 2
        #expect(h.transport.requests.count == previous + 1)
        previous = h.transport.requests.count
        h.clock.advance(by: 60)
        _ = try await sdk.flush()                               // failure 3 → budget spent → dropped, not retried forever
        #expect(h.transport.requests.count == previous + 1)
        let diag = await sdk.diagnostics()
        #expect(diag.pendingEvents == 0)
        #expect(diag.dropped[.maxAttempts] == 2)
        await sdk.shutdown()
    }

    @Test func authFailurePausesUploadsUntilCredentialsChange() async throws {
        let sdk = try await h.makeSDK()
        try await trackMany(sdk, 1)
        h.transport.setHandler { _ in .authenticationFailed }
        let first = try await sdk.flush()
        guard case .authenticationRequired = first.status else { return fail("\(first.status)") }
        let count = h.transport.requests.count

        h.clock.advance(by: 30)
        let second = try await sdk.flush()
        guard case .authenticationRequired = second.status else { return fail("\(second.status)") }
        #expect(h.transport.requests.count == count, "paused: no retry storm on 401")
        let queued = await pending(sdk)
        #expect(queued == 2, "events retained")

        h.transport.setHandler { FakeTransport.ackAll($0) }
        await sdk.credentialsDidChange()
        let third = try await sdk.flush()
        #expect(third.status == .completed)
        await sdk.shutdown()
    }

    @Test func offlineRetainsEventsWithoutSpendingAttemptsAndResumesWhenOnline() async throws {
        h.connectivity.set(.offline)
        let sdk = try await h.makeSDK { $0.upload.retry.maxAttempts = 1 }
        try await trackMany(sdk, 2)
        for _ in 0..<5 {
            let r = try await sdk.flush()
            #expect(r.status == .offline)
        }
        #expect(h.transport.requests.isEmpty)

        h.connectivity.set(.wifi)
        let r = try await sdk.flush()
        #expect(r.status == .completed)
        #expect(h.transport.requests.flatMap(\.events).count == 3)
        await sdk.shutdown()
    }

    @Test func unmeteredPolicyBlocksCellular() async throws {
        h.connectivity.set(.cellular)
        let sdk = try await h.makeSDK { $0.upload.networkPolicy = .unmeteredOnly }
        try await trackMany(sdk, 1)
        let blocked = try await sdk.flush()
        #expect(blocked.status == .blockedByNetworkPolicy)
        try sdk.updateUploadSettings { $0.networkPolicy = .any }
        let ok = try await sdk.flush()
        #expect(ok.status == .completed)
        await sdk.shutdown()
    }

    @Test func poisonEventIsIsolatedByBisectionAndDroppedWhileOthersDeliver() async throws {
        let sdk = try await h.makeSDK()
        try await trackMany(sdk, 7)                             // 8 events incl. session_start
        let poison = Locked<String?>(nil)
        h.transport.setHandler { request in
            let ids = request.events.map(\.eventID)
            if poison.withLock({ $0 }) == nil { poison.withLock { $0 = ids[3] } }
            if ids.contains(poison.withLock { $0 }!) { return .payloadRejected(status: 422) }
            return FakeTransport.ackAll(request)
        }
        let report = try await sdk.flush()
        #expect(report.status == .completed)
        #expect(report.acknowledgedEvents == 7)
        let diag = await sdk.diagnostics()
        #expect(diag.dropped[.permanentlyRejected] == 1)
        #expect(diag.pendingEvents == 0)
        await sdk.shutdown()
    }

    // MARK: Batching

    @Test func batchesRespectCountAndByteLimits() async throws {
        h.connectivity.set(.offline)                            // keep the threshold trigger from uploading while we fill the queue
        let sdk = try await h.makeSDK { $0.upload.maxBatchEvents = 10; $0.limits.maxEventBytes = 1024 }
        try await trackMany(sdk, 24)                            // 25 with session_start
        h.connectivity.set(.wifi)
        _ = try await sdk.flush()
        #expect(h.transport.requests.map { $0.events.count } == [10, 10, 5])

        let limit = 3_000
        try sdk.updateUploadSettings { $0.maxBatchBytes = limit; $0.maxBatchEvents = 500 }
        try await trackMany(sdk, 40)
        _ = try await sdk.flush()
        for request in h.transport.requests.dropFirst(3) {
            #expect(try request.encodedBody().count <= limit, "byte limit is exact because payloads are stored as wire JSON")
        }
        await sdk.shutdown()
    }

    @Test func thresholdTriggersUploadWithoutExplicitFlush() async throws {
        let sdk = try await h.makeSDK { $0.upload.maxBatchEvents = 5 }
        try await trackMany(sdk, 5)
        await eventually { self.h.transport.requests.flatMap(\.events).count >= 5 }
        await sdk.shutdown()
    }

    // MARK: Concurrency

    @Test func concurrentFlushesNeverOverlapUploadsAndEventsAreSentOnce() async throws {
        let sdk = try await h.makeSDK()
        try await trackMany(sdk, 5)
        let gate = AsyncGate()
        h.transport.setHandler { request in
            await gate.wait()                                    // hold the single in-flight request open
            return FakeTransport.ackAll(request)
        }
        async let f1 = sdk.flush(); async let f2 = sdk.flush(); async let f3 = sdk.flush()
        async let f4 = sdk.flush(); async let f5 = sdk.flush()
        await eventually { !self.h.transport.requests.isEmpty }
        try await Task.sleep(nanoseconds: 50_000_000)            // give any (incorrect) second upload time to start
        #expect(h.transport.maxConcurrentRequests == 1)
        await gate.open()
        let reports = try await [f1, f2, f3, f4, f5]
        #expect(reports.allSatisfy { $0.status == .completed })
        let sent = h.transport.requests.flatMap { $0.events.map(\.eventID) }
        #expect(sent.count == Set(sent).count, "no event uploaded twice")
        #expect(h.transport.maxConcurrentRequests == 1)
        await sdk.shutdown()
    }
}
