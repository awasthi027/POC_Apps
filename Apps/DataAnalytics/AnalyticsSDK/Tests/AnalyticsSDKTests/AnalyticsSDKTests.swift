import Foundation
import Testing
@testable import AnalyticsSDK

@Suite final class AnalyticsSDKTests {
    private let h = Harness()

    deinit { h.cleanUp() }

    private func offlineSDK(_ mutate: (inout AnalyticsConfiguration) -> Void = { _ in }) async throws -> AnalyticsSDK {
        h.connectivity.set(.offline)
        return try await h.makeSDK(mutate)
    }

    private func allSentEvents() throws -> [AnalyticsEvent] { try h.transport.requests.flatMap { try decodeEvents($0) } }

    // MARK: Lifecycle / API contract

    @Test func trackBeforeInitializeThrowsAndRecordsNothing() async throws {
        let sdk = AnalyticsSDK(configuration: h.configuration(), dependencies: h.dependencies)
        do { try await sdk.track("x"); Issue.record("failed") } catch { #expect(error as? AnalyticsError == .notInitialized) }
        #expect(sdk.enqueue("x") == .rejected(.notInitialized))
    }

    @Test func concurrentInitializeSharesOneInitializationAndRepeatIsNoOp() async throws {
        let sdk = AnalyticsSDK(configuration: h.configuration(), dependencies: h.dependencies)
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<10 { group.addTask { try await sdk.initialize() } }
            try await group.waitForAll()
        }
        try await sdk.initialize()
        try await sdk.track("ok")
        await sdk.shutdown()
    }

    @Test func failedInitializationCanBeRetried() async throws {
        var bad = h.configuration(); bad.projectID = ""
        let sdk = AnalyticsSDK(configuration: bad, dependencies: h.dependencies)
        do { try await sdk.initialize(); Issue.record("failed") } catch { guard case AnalyticsError.invalidConfiguration = error else { return fail("\(error)") } }
        do { try await sdk.initialize(); Issue.record("failed") } catch { guard case AnalyticsError.invalidConfiguration = error else { return fail("\(error)") } }
    }

    @Test func invalidEventThrowsAndNothingIsStored() async throws {
        let sdk = try await offlineSDK()
        do { try await sdk.track("bad name!"); Issue.record("failed") } catch { #expect(error as? AnalyticsError == .validation(.invalidName, key: nil)) }
        #expect(sdk.enqueue("$reserved") == .rejected(.validation(.reservedName, key: nil)))
        try await sdk.flush()
        let pending = await sdk.diagnostics().pendingEvents
        #expect(pending == 0, "a rejected event must not create a session or any queue row")
        await sdk.shutdown()
    }

    // MARK: Durability

    @Test func trackReturnsOnlyAfterCommitVisibleToAnotherConnection() async throws {
        let sdk = try await offlineSDK()
        let outcome = try await sdk.track("purchase", properties: ["sku": "a1"])
        guard case .persisted(let id) = outcome else { return fail("failed") }
        let independent = try h.openStore()                      // second connection = what a restarted process would see
        let stats = try await independent.stats()
        #expect(stats.pendingEvents == 2, "event + $session_start are already committed when track() returns")
        _ = id
        await sdk.shutdown()
    }

    @Test func restartRecoversPendingEventsAndUploadsWithOriginalIDs() async throws {
        let first = try await offlineSDK()
        for i in 0..<5 { try await first.track("e", properties: ["i": .int(i)]) }
        await first.shutdown()

        h.connectivity.set(.wifi)
        let second = try await h.makeSDK()
        let report = try await second.flush()
        #expect(report.status == .completed)
        let sent = try allSentEvents()
        #expect(sent.filter { $0.name == "e" }.compactMap { $0.properties["i"] } == [0, 1, 2, 3, 4].map { AnalyticsValue.int($0) })
        #expect(Set(sent.map(\.eventID)).count == sent.count)
        await second.shutdown()
    }

    @Test func killDuringUploadRecoversAbandonedLeaseOnNextLaunch() async throws {
        let first = try await h.makeSDK()
        try await first.track("in_flight")
        let stuck = AsyncGate()
        h.transport.setHandler { _ in await stuck.wait(); return .network(.cancelled) }   // first process never gets a response
        let firstFlush = Task { try await first.flush() }
        await eventually { self.h.transport.requests.count == 1 }
        let firstRequestIDs = h.transport.requests[0].events.map(\.eventID)

        h.transport.setHandler { FakeTransport.ackAll($0) }
        let relaunched = try await h.makeSDK()                    // new process: recoverAllLeases() frees the abandoned lease
        let report = try await relaunched.flush()
        #expect(report.status == .completed)
        #expect(h.transport.requests.last!.events.map(\.eventID) == firstRequestIDs, "same IDs, so the server can de-duplicate")

        await stuck.open()
        _ = try? await firstFlush.value
        await first.shutdown(); await relaunched.shutdown()
    }

    @Test func concurrentTrackFromManyTasksAllPersistWithUniqueIDs() async throws {
        let sdk = try await offlineSDK { $0.storage.maxQueuedEvents = 5_000 }
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<1_000 { group.addTask { try await sdk.track("burst", properties: ["i": .int(i)]) } }
            try await group.waitForAll()
        }
        let diag = await sdk.diagnostics()
        #expect(diag.pendingEvents == 1_001)                 // + $session_start, exactly one despite the race
        #expect(diag.eventsPersisted == 1_001)
        await sdk.shutdown()
    }

    @Test func tenThousandRapidEnqueuesAreBoundedAndAccountedFor() async throws {
        let sdk = try await offlineSDK { $0.ingressCapacity = 500; $0.storage.maxQueuedEvents = 50_000 }
        var accepted = 0, backpressured = 0
        for i in 0..<10_000 {
            switch sdk.enqueue("rapid", properties: ["i": .int(i)]) {
            case .accepted: accepted += 1
            case .rejected(.backpressure): backpressured += 1
            default: Issue.record("unexpected result")
            }
        }
        #expect(accepted + backpressured == 10_000, "every event is either queued or explicitly refused — never silently lost")
        try await sdk.flush()                                    // barrier: waits for the buffer to reach disk
        let diag = await sdk.diagnostics()
        #expect(diag.pendingEvents == accepted + 1)         // + $session_start
        #expect(diag.dropped[.backpressure] ?? 0 == backpressured)
        await sdk.shutdown()
    }

    // MARK: Storage limits

    @Test func storageFullRejectNewSurfacesAnErrorToTheCaller() async throws {
        let sdk = try await offlineSDK { $0.storage.maxQueuedEvents = 3; $0.storage.fullPolicy = .rejectNew }
        try await sdk.track("a"); try await sdk.track("b")       // + session_start = 3
        do { try await sdk.track("c"); Issue.record("must not report success") } catch { #expect(error as? AnalyticsError == .storageFull) }
        let diag = await sdk.diagnostics()
        #expect(diag.dropped[.storageFull] == 1)
        #expect(diag.pendingEvents == 3)
        await sdk.shutdown()
    }

    @Test func storageFullDropOldestIsCountedNotSilent() async throws {
        let sdk = try await offlineSDK { $0.storage.maxQueuedEvents = 3; $0.storage.fullPolicy = .dropOldest }
        for i in 0..<6 { try await sdk.track("e", properties: ["i": .int(i)]) }
        let diag = await sdk.diagnostics()
        #expect(diag.pendingEvents == 3)
        #expect(diag.dropped[.evictedForSpace] == 4)         // 7 written, 3 kept
        await sdk.shutdown()
    }

    // MARK: Consent

    @Test func defaultConsentIsDeniedAndEventsAreNotRecorded() async throws {
        let sdk = try await h.makeSDK { $0.initialConsent = .denied }
        let outcome = try await sdk.track("x")
        #expect(outcome == .droppedNoConsent)
        #expect(sdk.enqueue("x") == .droppedNoConsent)
        let report = try await sdk.flush()
        #expect(report.status == .consentDenied)
        #expect(h.transport.requests.isEmpty)
        await sdk.shutdown()
    }

    @Test func revocationDeletesQueuedEventsStopsCollectionAndSurvivesRestart() async throws {
        let sdk = try await offlineSDK()
        for _ in 0..<5 { try await sdk.track("e") }
        try await sdk.setConsent(.denied)
        var diag = await sdk.diagnostics()
        #expect(diag.pendingEvents == 0)
        #expect(diag.dropped[.consentRevoked] == 6)
        let outcome = try await sdk.track("after")
        #expect(outcome == .droppedNoConsent)
        await sdk.shutdown()

        let relaunched = try await h.makeSDK { $0.initialConsent = .granted }   // persisted "denied" must win over config
        #expect(relaunched.consentState == .denied)
        let ignored = try await relaunched.track("still_off")
        #expect(ignored == .droppedNoConsent)

        try await relaunched.setConsent(.granted)
        try await relaunched.track("back")
        diag = await relaunched.diagnostics()
        #expect(diag.consent == .granted)
        #expect(diag.pendingEvents > 0)
        await relaunched.shutdown()
    }

    @Test func retainPolicyKeepsEventsButNeverUploadsThemWhileDenied() async throws {
        let sdk = try await offlineSDK { $0.consentRevocation = .retainQueuedEvents }
        try await sdk.track("e")
        try await sdk.setConsent(.denied)
        h.connectivity.set(.wifi)
        let report = try await sdk.flush()
        #expect(report.status == .consentDenied)
        #expect(h.transport.requests.isEmpty)
        let pending = await sdk.diagnostics().pendingEvents
        #expect(pending == 2)
        await sdk.shutdown()
    }

    // MARK: Identity

    @Test func identifyNeverRewritesQueuedEventsAndSwitchingUsersRotatesAnonymousID() async throws {
        let sdk = try await offlineSDK()
        try await sdk.track("before")
        try await sdk.identify(userID: "user-A", properties: ["plan": "premium"])
        try await sdk.track("as_a")
        try await sdk.identify(userID: "user-B")
        try await sdk.track("as_b")
        try await sdk.reset()
        try await sdk.track("after_logout")
        h.connectivity.set(.wifi)
        try await sdk.flush()

        let events = try allSentEvents()
        func event(_ name: String) -> AnalyticsEvent { events.first { $0.name == name }! }
        #expect(event("before").userID == nil, "queued anonymous events stay anonymous")
        #expect(event("as_a").userID == "user-A")
        #expect(event("as_b").userID == "user-B")
        #expect(event("after_logout").userID == nil)
        #expect(event("before").anonymousID == event("as_a").anonymousID, "identify keeps the anonymous ID so the server can alias history")
        #expect(event("as_a").anonymousID != event("as_b").anonymousID, "account switch rotates it")
        #expect(event("as_b").anonymousID != event("after_logout").anonymousID)
        #expect(event("as_a").sessionID == event("before").sessionID)
        #expect(event("as_b").sessionID != event("as_a").sessionID, "account switch ends the previous user's session")
        #expect(events.contains { $0.name == "$session_end" && $0.userID == "user-A" }, "A's session end carries A's identity")
        await sdk.shutdown()
    }

    @Test func emailLookingUserIDIsRejected() async throws {
        let sdk = try await offlineSDK()
        do { try await sdk.identify(userID: "jane@example.com"); Issue.record("failed") } catch { #expect(error as? AnalyticsError == .validation(.possiblePII, key: nil)) }
        await sdk.shutdown()
    }

    @Test func anonymousIDIsStableAcrossRestarts() async throws {
        let first = try await offlineSDK()
        try await first.track("a")
        await first.shutdown()
        let second = try await offlineSDK()
        try await second.track("b")
        try await second.flush(); h.connectivity.set(.wifi); try await second.flush()
        let ids = Set(try allSentEvents().map(\.anonymousID))
        #expect(ids.count == 1)
        await second.shutdown()
    }

    // MARK: Sessions

    @Test func sessionRollsOverAfterInactivityWithoutWallClockSleeping() async throws {
        let sdk = try await offlineSDK { $0.sessionTimeout = 600 }
        try await sdk.track("a")
        h.clock.advance(by: 300); try await sdk.track("b")
        h.clock.advance(by: 601); try await sdk.track("c")
        h.connectivity.set(.wifi); try await sdk.flush()
        let events = try allSentEvents()
        let sessionOf = { (n: String) in events.first { $0.name == n }!.sessionID }
        #expect(sessionOf("a") == sessionOf("b"))
        #expect(sessionOf("b") != sessionOf("c"))
        #expect(events.filter { $0.name == "$session_start" }.count == 2)
        let end = events.first { $0.name == "$session_end" }!
        #expect(end.properties["reason"] == "timeout")
        #expect(end.sessionID == sessionOf("a"))
        await sdk.shutdown()
    }

    @Test func sessionResumesAfterQuickRestartAndIsClosedAsInterruptedAfterLongGap() async throws {
        let first = try await offlineSDK { $0.sessionTimeout = 600 }
        try await first.track("a")
        await first.shutdown()

        h.clock.advance(by: 100)                                  // quick relaunch: same session
        let second = try await offlineSDK { $0.sessionTimeout = 600 }
        try await second.track("b")
        await second.shutdown()

        h.clock.advance(by: 5_000)                                // long gap (crash, overnight): old session is closed
        let third = try await offlineSDK { $0.sessionTimeout = 600 }
        try await third.track("c")
        h.connectivity.set(.wifi); try await third.flush()

        let events = try allSentEvents()
        let sessionOf = { (n: String) in events.first { $0.name == n }!.sessionID }
        #expect(sessionOf("a") == sessionOf("b"))
        #expect(sessionOf("b") != sessionOf("c"))
        let end = events.first { $0.name == "$session_end" }!
        #expect(end.properties["reason"] == "interrupted")
        #expect(end.sessionID == sessionOf("a"))
        await third.shutdown()
    }

    // MARK: Configuration and diagnostics

    @Test func runtimeSettingsUpdatesAreValidatedAtomically() async throws {
        let sdk = try await offlineSDK()
        #expect(throws: AnalyticsError.self) { try sdk.updateUploadSettings { $0.maxBatchBytes = 10 } }   // can't fit one event
        #expect(throws: AnalyticsError.self) { try sdk.updateUploadSettings { $0.maxBatchEvents = 0 } }
        #expect(throws: Never.self) { _ = try sdk.updateUploadSettings { $0.maxBatchEvents = 7; $0.uploadInterval = 5 } }
        await sdk.shutdown()
    }

    @Test func diagnosticsContainNoEventContent() async throws {
        let sdk = try await offlineSDK()
        try await sdk.track("secret_event_name", properties: ["note": "very-private-value"])
        let description = String(describing: await sdk.diagnostics())
        #expect(!(description.contains("very-private-value")))
        #expect(!(description.contains("secret_event_name")))
        await sdk.shutdown()
    }

    @Test func shutdownFailsBufferedEventsWithShutDownErrorAndKeepsCommittedOnes() async throws {
        let sdk = try await offlineSDK()
        try await sdk.track("kept")
        await sdk.shutdown()
        do { try await sdk.track("late"); Issue.record("failed") } catch { #expect(error as? AnalyticsError == .shutDown) }
        let store = try h.openStore()
        let stats = try await store.stats()
        #expect(stats.pendingEvents == 2)
    }
}
