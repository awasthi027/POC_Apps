import Foundation

/// Public facade. Deliberately thin: it owns the lifecycle state machine and translates between the public
/// contract and internal components. No analytics logic lives here.
///
/// Contract summary (details in DESIGN.md):
///  * Every `async` method is nonisolated, so calling it from the main actor hops to the cooperative pool;
///    no database or network work ever runs on the main thread, and nothing blocks synchronously.
///  * `track` returns only after the SQLite transaction containing the event has committed, or throws.
///  * `enqueue` is the non-blocking, fire-and-forget variant: it returns once the event is in the bounded
///    in-memory buffer (not yet durable) and reports later persistence failure through `onError`/diagnostics.
///  * Invalid events throw (`track`) or return `.rejected` (`enqueue`); they are never silently discarded.
///  * `initialize()` is idempotent; concurrent calls share one initialization.
///  * `flush()` waits for a pass that starts after the call; `requestFlush()` only asks.
///  * Delivery is at-least-once with stable event IDs; the server de-duplicates. Not exactly-once.
public final class AnalyticsSDK: Sendable {
    private enum Phase {
        case idle
        case initializing(Task<SDKRuntime, Error>)
        case ready(SDKRuntime)
        case shutDown
    }

    private let configuration: AnalyticsConfiguration
    private let dependencies: AnalyticsDependencies
    private let phase = Locked<Phase>(.idle)
    private let diagnosticsAggregator: DiagnosticsAggregator

    public convenience init(configuration: AnalyticsConfiguration) {
        self.init(configuration: configuration, dependencies: .live())
    }

    init(configuration: AnalyticsConfiguration, dependencies: AnalyticsDependencies) {
        self.configuration = configuration
        self.dependencies = dependencies
        self.diagnosticsAggregator = DiagnosticsAggregator(forwardingTo: configuration.metricsSink)
    }

    // MARK: Initialization

    /// Validates configuration, opens/migrates/recovers the database, restores identity/session/consent, and
    /// starts uploads. Safe to call repeatedly and concurrently. A failed attempt may be retried.
    public func initialize() async throws {
        let task: Task<SDKRuntime, Error> = try phase.withLock { phase in
            switch phase {
            case .initializing(let t): return t
            case .ready(let runtime): return Task { runtime }
            case .shutDown: throw AnalyticsError.shutDown
            case .idle:
                // Unstructured on purpose: caller cancellation must not abort a shared initialization.
                let t = Task { try await self.bootstrap() }
                phase = .initializing(t)
                return t
            }
        }
        do {
            let runtime = try await task.value
            phase.withLock { phase in
                if case .initializing(let current) = phase, current == task { phase = .ready(runtime) }
            }
        } catch {
            phase.withLock { phase in
                if case .initializing(let current) = phase, current == task { phase = .idle }
            }
            throw error
        }
    }

    // MARK: Tracking

    /// Records an event; returns after the transaction commits. Throws on validation, backpressure, or
    /// persistence failure — in which case the event is NOT recorded and will never be uploaded.
    @discardableResult
    public func track(_ name: String, properties: [String: AnalyticsValue] = [:]) async throws -> TrackOutcome {
        try await record { runtime, id, completion in
            runtime.buildTrack(eventID: id, name: name, properties: properties, completion: completion)
        }
    }

    @discardableResult
    public func trackScreen(_ screenName: String, properties: [String: AnalyticsValue] = [:]) async throws -> TrackOutcome {
        try await record { runtime, id, completion in
            runtime.buildScreen(eventID: id, screenName: screenName, properties: properties, completion: completion)
        }
    }

    /// Non-blocking variant for hot paths. Never suspends and never touches the database on the caller's thread.
    @discardableResult
    public func enqueue(_ name: String, properties: [String: AnalyticsValue] = [:]) -> EnqueueResult {
        guard let runtime = readyRuntime() else { return .rejected(.notInitialized) }
        let id = runtime.makeID()
        switch runtime.ingress.submit({ runtime.buildTrack(eventID: id, name: name, properties: properties, completion: nil) }) {
        case .queued: return .accepted(eventID: id)
        case .noConsent: return .droppedNoConsent
        case .failed(let error):
            if error == .backpressure { runtime.diagnostics.record(.eventsDropped(.backpressure, 1)) }
            return .rejected(error)
        }
    }

    // MARK: Identity and sessions

    /// Associates subsequent events with `userID`. Already-queued events are NOT rewritten; the server joins
    /// pre-identify history through `anonymous_id`. Switching users ends the previous user's session and rotates
    /// the anonymous ID. Prefer opaque IDs over e-mail addresses (e-mail-looking IDs are rejected by default).
    @discardableResult
    public func identify(userID: String, properties: [String: AnalyticsValue] = [:]) async throws -> TrackOutcome {
        try await record { runtime, id, completion in
            runtime.buildIdentify(eventID: id, userID: userID, properties: properties, completion: completion)
        }
    }

    /// Logout: ends the session, forgets the user and rotates the anonymous ID. Queued events keep their identity.
    public func reset() async throws {
        try await record { runtime, _, completion in runtime.buildReset(completion: completion) }
    }

    public func endSession() async throws {
        try await record { runtime, _, completion in runtime.buildEndSession(completion: completion) }
    }

    // MARK: Consent

    /// Granting resumes collection and uploads. Revoking takes effect immediately for new events, discards the
    /// in-memory buffer, persists the decision *before* deleting (so a crash cannot resurrect collection), and
    /// then applies `consentRevocation`. An upload already on the wire when consent is revoked cannot be recalled.
    public func setConsent(_ state: ConsentState) async throws {
        let runtime = try requireRuntime()
        let write = MetadataWrite(key: MetadataKey.consent, value: state.rawValue)
        switch state {
        case .granted:
            runtime.consent.set(.granted)
            try await runtime.store.setMetadata([write])
            await runtime.coordinator.requestPass()
        case .denied:
            _ = runtime.ingress.atomically(discarding: .consentDenied) { runtime.consent.set(.denied) }
            try await runtime.store.setMetadata([write])
            await runtime.ingress.waitUntilIdle()   // an in-flight commit must finish before we delete
            if configuration.consentRevocation == .deleteQueuedEvents {
                try await purgeAfterRevocation(runtime)
            }
        }
    }

    public var consentState: ConsentState { readyRuntime()?.consent.current ?? configuration.initialConsent }

    // MARK: Upload control

    /// Waits until a pass that began after this call completes (or is blocked: offline, backoff, auth, consent).
    /// Events accepted before the call are committed first. Concurrent calls share passes.
    @discardableResult
    public func flush() async throws -> FlushReport {
        let runtime = try requireRuntime()
        guard runtime.consent.isGranted else { return FlushReport(status: .consentDenied, acknowledgedEvents: 0, remainingEvents: 0) }
        try await runtime.ingress.barrier()
        return await runtime.coordinator.flush()
    }

    /// Fire-and-forget; coalesces repeated calls into at most one pending request.
    public func requestFlush() {
        guard let runtime = readyRuntime() else { return }
        let alreadyPending = runtime.flushRequested.withLock { pending -> Bool in let was = pending; pending = true; return was }
        if alreadyPending { return }
        Task {
            await runtime.coordinator.requestPass()
            runtime.flushRequested.withLock { $0 = false }
        }
    }

    /// Call after fixing a 401/403 condition (new token, corrected endpoint) to lift the upload pause.
    public func credentialsDidChange() async {
        await readyRuntime()?.coordinator.credentialsDidChange()
    }

    /// Applies to batches leased after the call. Throws if the new values are invalid; nothing changes then.
    public func updateUploadSettings(_ transform: (inout UploadSettings) -> Void) throws {
        let runtime = try requireRuntime()
        var updated = runtime.settings.withLock { $0 }
        transform(&updated)
        try updated.validate(limits: configuration.limits, projectID: configuration.projectID)
        runtime.settings.withLock { $0 = updated }
    }

    // MARK: App lifecycle

    public func applicationDidBecomeActive() async {
        guard let runtime = readyRuntime() else { return }
        _ = runtime.ingress.submit { runtime.buildLifecycleTouch() }
        await runtime.coordinator.requestPass()
    }

    /// Best effort: asks for extra background time, then flushes. If the OS refuses or revokes the time, nothing
    /// is lost — events are already durable and are uploaded on a later launch.
    public func applicationDidEnterBackground() async {
        guard readyRuntime() != nil else { return }
        await dependencies.backgroundRunner.run(name: "AnalyticsSDK.flush") { [weak self] in
            _ = try? await self?.flush()
        }
    }

    // MARK: Diagnostics and shutdown

    public func diagnostics() async -> AnalyticsDiagnosticsSnapshot {
        var snapshot = diagnosticsAggregator.snapshot()
        snapshot.consent = consentState
        guard let runtime = readyRuntime() else { return snapshot }
        if let stats = try? await runtime.store.stats() {
            snapshot.pendingEvents = stats.pendingEvents
            snapshot.leasedEvents = stats.leasedEvents
            snapshot.queuePayloadBytes = stats.payloadBytes
            snapshot.databaseDiskBytes = stats.diskBytes
            snapshot.oldestEventAge = stats.oldestEventAt.map { runtime.clock.now().timeIntervalSince($0) }
        }
        let status = await runtime.coordinator.status()
        snapshot.uploadsPausedUntil = status.pausedUntil
        snapshot.backingOffUntil = status.backoffUntil
        return snapshot
    }

    /// Stops uploads, fails buffered-but-uncommitted events with `.shutDown`, and closes the database. Committed
    /// events stay on disk for the next launch.
    public func shutdown() async {
        let runtime: SDKRuntime? = phase.withLock { phase in
            defer { phase = .shutDown }
            if case .ready(let r) = phase { return r }
            return nil
        }
        guard let runtime else { return }
        runtime.observers.withLock { observers in
            observers.forEach(NotificationCenter.default.removeObserver)
            observers = []
        }
        runtime.ingress.close()
        await runtime.ingress.waitUntilIdle()
        await runtime.coordinator.shutdown()
        runtime.connectivity.stop()
        await runtime.store.close()
    }

    // MARK: Internals

    private func readyRuntime() -> SDKRuntime? {
        phase.withLock { if case .ready(let r) = $0 { return r } else { return nil } }
    }

    private func requireRuntime() throws -> SDKRuntime {
        try phase.withLock { phase in
            switch phase {
            case .ready(let r): return r
            case .shutDown: throw AnalyticsError.shutDown
            case .idle, .initializing: throw AnalyticsError.notInitialized
            }
        }
    }

    @discardableResult
    private func record(_ build: @escaping @Sendable (SDKRuntime, String, @escaping EventIngress.Completion) -> EventIngress.Built) async throws -> TrackOutcome {
        let runtime = try requireRuntime()
        let started = runtime.clock.now()
        let eventID = runtime.makeID()
        do {
            let outcome: TrackOutcome = try await withCheckedThrowingContinuation { cont in
                let completion: EventIngress.Completion = { result in
                    cont.resume(with: result.map { TrackOutcome.persisted(eventID: eventID) }.mapError { $0 as Error })
                }
                switch runtime.ingress.submit({ build(runtime, eventID, completion) }) {
                case .queued: break   // `completion` fires after COMMIT
                case .noConsent: cont.resume(returning: .droppedNoConsent)
                case .failed(let error):
                    if error == .backpressure { runtime.diagnostics.record(.eventsDropped(.backpressure, 1)) }
                    cont.resume(throwing: error)
                }
            }
            runtime.diagnostics.record(.trackLatency(runtime.clock.now().timeIntervalSince(started)))
            return outcome
        } catch AnalyticsError.consentDenied {
            return .droppedNoConsent   // consent was revoked while the event sat in the buffer
        }
    }

    private func purgeAfterRevocation(_ runtime: SDKRuntime) async throws {
        let removed = try await runtime.store.deleteAllEvents()
        if removed > 0 { runtime.diagnostics.record(.eventsDropped(.consentRevoked, removed)) }
        // Forget identity and session too: nothing linkable to the revoked user should outlive the events.
        _ = runtime.sessions.end(now: runtime.clock.now(), reason: .explicit)
        runtime.identity.reset(newAnonymousID: runtime.makeID())
        var writes = runtime.identity.drainDirty()
        if let session = runtime.sessions.drainDirty() { writes.append(session) }
        try await runtime.store.setMetadata(writes)
    }

    private func bootstrap() async throws -> SDKRuntime {
        try configuration.validate()
        let diagnostics = diagnosticsAggregator
        let deps = dependencies
        let clock = deps.clock

        let store = try deps.makeStore(configuration) { diagnostics.record(.databaseRebuilt) }
        do {
            // Previous process is gone: every lease it held is abandoned.
            _ = try await store.recoverAllLeases()
            _ = try await store.purgeExpired(createdBefore: clock.now().addingTimeInterval(-configuration.storage.retention))

            let consentValue = try await store.metadata(MetadataKey.consent).flatMap(ConsentState.init(rawValue:))
            let consent = ConsentManager(initial: consentValue ?? configuration.initialConsent)
            if consent.current == .denied && configuration.consentRevocation == .deleteQueuedEvents {
                // Finishes a revocation that was interrupted by a crash between "persist denied" and "delete".
                _ = try await store.deleteAllEvents()
            }

            let anonymous = try await store.metadata(MetadataKey.anonymousID)
            let user = try await store.metadata(MetadataKey.userID)
            let identity = IdentityManager(anonymousID: anonymous ?? deps.makeID(), userID: user, needsPersist: anonymous == nil)

            let sessions = SessionManager(timeout: configuration.sessionTimeout, makeID: deps.makeID)
            let persistedSession = try await store.metadata(MetadataKey.session)
                .flatMap { $0.data(using: .utf8) }
                .flatMap { try? JSONDecoder().decode(SessionManager.State.self, from: $0) }
            sessions.restore(persistedSession, now: clock.now())

            let settings = Locked(configuration.upload)
            let onError = configuration.onError ?? { _ in }
            let coordinator = UploadCoordinator(
                store: store, transport: deps.makeTransport(configuration, clock, settings), clock: clock,
                connectivity: deps.connectivity, settings: settings,
                configuration: .init(projectID: configuration.projectID, leaseDuration: configuration.storage.leaseDuration,
                                     retention: configuration.storage.retention),
                isUploadAllowed: { consent.isGranted }, diagnostics: diagnostics, makeID: deps.makeID,
                random: deps.random, onError: onError)

            let ingress = EventIngress(
                store: store, capacity: configuration.ingressCapacity,
                limits: StorageLimits(maxEvents: configuration.storage.maxQueuedEvents,
                                      maxBytes: configuration.storage.maxQueuedBytes,
                                      fullPolicy: configuration.storage.fullPolicy),
                metadataSource: {
                    var writes = identity.drainDirty()
                    if let session = sessions.drainDirty() { writes.append(session) }
                    return writes
                },
                metadataRestore: { identity.markDirty(); sessions.markDirty() },
                diagnostics: diagnostics,
                onCommitted: { count in Task { await coordinator.noteEnqueued(count) } },
                onError: onError)

            let processor = EventProcessor(limits: configuration.limits, piiPolicy: configuration.piiPolicy,
                                           contextProvider: deps.makeContextProvider(deps.connectivity))
            let runtime = SDKRuntime(configuration: configuration, clock: clock, store: store, connectivity: deps.connectivity,
                                     ingress: ingress, processor: processor, sessions: sessions, identity: identity,
                                     consent: consent, coordinator: coordinator, settings: settings,
                                     diagnostics: diagnostics, makeID: deps.makeID)

            deps.connectivity.start()
            await coordinator.start()
            if configuration.observesAppLifecycle { installLifecycleObservers(runtime) }
            return runtime
        } catch {
            await store.close()
            throw error
        }
    }

    private func installLifecycleObservers(_ runtime: SDKRuntime) {
        // Notification names are used as strings so the SDK needs no UIKit import (and stays testable on macOS).
        let center = NotificationCenter.default
        let active = center.addObserver(forName: Notification.Name("UIApplicationDidBecomeActiveNotification"),
                                        object: nil, queue: nil) { [weak self] _ in
            Task { await self?.applicationDidBecomeActive() }
        }
        let background = center.addObserver(forName: Notification.Name("UIApplicationDidEnterBackgroundNotification"),
                                           object: nil, queue: nil) { [weak self] _ in
            Task { await self?.applicationDidEnterBackground() }
        }
        runtime.observers.withLock { $0 = [active, background] }
    }
}
