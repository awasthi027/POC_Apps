import Foundation

public enum FlushStatus: Sendable, Equatable {
    /// Nothing eligible remains (everything was acknowledged, or is waiting on its own retry time).
    case completed
    case consentDenied
    case offline
    case blockedByNetworkPolicy
    /// Server- or failure-driven backoff is active (429 / 5xx / timeout / unconfirmed events).
    case backingOff(until: Date)
    /// 401 after refresh, or a configuration error (403 etc.). Needs the host to act; see `credentialsDidChange()`.
    case authenticationRequired(until: Date)
    case storageFailure
    case stopped
}

public struct FlushReport: Sendable, Equatable {
    public var status: FlushStatus
    /// Events the server confirmed during the pass(es) this flush waited for (shared with concurrent flushes).
    public var acknowledgedEvents: Int
    /// Events still queued (including ones waiting for backoff).
    public var remainingEvents: Int
}

/// Owns "when and what to upload".
///
/// Concurrency model — one upload worker:
///  * The actor guards only the coordinator's own bookkeeping. It is **released** during every `await`
///    (store I/O and, above all, the network request), so a slow upload never blocks triggers or `flush()`.
///  * At most one worker task exists (`workerRunning`). Triggers do not start uploads; they bump
///    `requestedGeneration`. The worker repeats passes until `completedGeneration` catches up, so any number
///    of simultaneous triggers collapse into one extra pass instead of overlapping uploads.
///  * Exclusive ownership of events is additionally enforced in the database (lease_id), so correctness does
///    not depend on there being exactly one worker. Throughput is bounded by one in-flight request:
///    batch_size / RTT (see DEFENSE.md, "1,000 events per second").
actor UploadCoordinator {
    struct Configuration: Sendable {
        var projectID: String
        var leaseDuration: TimeInterval
        var retention: TimeInterval
    }

    private struct PassResult { var status: FlushStatus; var acknowledged: Int }
    private struct Step { var acknowledged: Int; var stop: FlushStatus? }
    private struct Waiter { var generation: Int; var continuation: CheckedContinuation<PassResult, Never> }

    private let store: any EventStore
    private let transport: any AnalyticsTransport
    private let clock: any AnalyticsClock
    private let connectivity: any ConnectivityMonitor
    private let settings: Locked<UploadSettings>
    private let configuration: Configuration
    private let isUploadAllowed: @Sendable () -> Bool
    private let diagnostics: DiagnosticsAggregator
    private let makeID: @Sendable () -> String
    private let random: @Sendable () -> Double
    private let onError: @Sendable (AnalyticsError) -> Void

    private var requestedGeneration = 0
    private var completedGeneration = 0
    private var workerRunning = false
    private var workerTask: Task<Void, Never>?
    private var waiters: [Waiter] = []
    private var backgroundTasks: [Task<Void, Never>] = []
    private var wakeTask: Task<Void, Never>?

    private var consecutiveFailures = 0
    private var backoffUntil: Date?
    private var pausedUntil: Date?
    private var adaptiveBatchLimit: Int?
    private var eventsSinceLastPass = 0
    private var stopped = false

    init(store: any EventStore, transport: any AnalyticsTransport, clock: any AnalyticsClock,
         connectivity: any ConnectivityMonitor, settings: Locked<UploadSettings>, configuration: Configuration,
         isUploadAllowed: @escaping @Sendable () -> Bool, diagnostics: DiagnosticsAggregator,
         makeID: @escaping @Sendable () -> String, random: @escaping @Sendable () -> Double,
         onError: @escaping @Sendable (AnalyticsError) -> Void) {
        self.store = store; self.transport = transport; self.clock = clock; self.connectivity = connectivity
        self.settings = settings; self.configuration = configuration; self.isUploadAllowed = isUploadAllowed
        self.diagnostics = diagnostics; self.makeID = makeID; self.random = random; self.onError = onError
    }

    // MARK: Triggers

    /// Starts the best-effort interval timer and the connectivity listener, and requests an initial pass so
    /// events recovered from a previous run are uploaded promptly.
    func start() {
        guard backgroundTasks.isEmpty, !stopped else { return }
        let clock = self.clock, connectivity = self.connectivity
        backgroundTasks.append(Task.detached { [weak self] in
            while !Task.isCancelled {
                guard let interval = await self?.currentInterval() else { return }
                do { try await clock.sleep(for: interval) } catch { return }
                await self?.requestPass()
            }
        })
        backgroundTasks.append(Task.detached { [weak self] in
            for await status in connectivity.updates() where status.isConnected { await self?.requestPass() }
        })
        requestPass()
    }

    /// Non-blocking: asks for a pass and returns immediately. Safe to call from any number of triggers.
    func requestPass() {
        guard !stopped else { return }
        requestedGeneration += 1
        startWorkerIfNeeded()
    }

    /// Threshold trigger: called after each durable commit with the number of events stored.
    func noteEnqueued(_ count: Int) {
        eventsSinceLastPass += count
        if eventsSinceLastPass >= settings.withLock({ $0.maxBatchEvents }) { requestPass() }
    }

    /// Waits for a pass that *starts after this call* to finish. Concurrent flushes share passes.
    func flush() async -> FlushReport {
        guard !stopped else { return FlushReport(status: .stopped, acknowledgedEvents: 0, remainingEvents: 0) }
        requestedGeneration += 1
        let mine = requestedGeneration
        startWorkerIfNeeded()
        // Registered synchronously (no suspension since the increment), so the worker cannot finish this
        // generation before the waiter exists.
        let result = await withCheckedContinuation { (c: CheckedContinuation<PassResult, Never>) in
            waiters.append(Waiter(generation: mine, continuation: c))
        }
        let remaining = (try? await store.stats().pendingEvents) ?? 0
        return FlushReport(status: result.status, acknowledgedEvents: result.acknowledged, remainingEvents: remaining)
    }

    /// The host fixed credentials (new token / config): lift the auth pause and try now.
    func credentialsDidChange() {
        pausedUntil = nil
        requestPass()
    }

    func shutdown() async {
        stopped = true
        backgroundTasks.forEach { $0.cancel() }
        backgroundTasks = []
        wakeTask?.cancel()
        let worker = workerTask
        worker?.cancel()
        await worker?.value
        let pending = waiters
        waiters = []
        pending.forEach { $0.continuation.resume(returning: PassResult(status: .stopped, acknowledged: 0)) }
    }

    func status() -> (pausedUntil: Date?, backoffUntil: Date?) { (pausedUntil, backoffUntil) }

    private func currentInterval() -> TimeInterval { settings.withLock { $0.uploadInterval } }

    // MARK: Worker

    private func startWorkerIfNeeded() {
        guard !workerRunning, !stopped else { return }
        workerRunning = true
        workerTask = Task { [weak self] in await self?.runWorker() }
    }

    private func runWorker() async {
        while completedGeneration < requestedGeneration && !stopped {
            let target = requestedGeneration
            let result = await performPass()
            completedGeneration = target
            let ready = waiters.filter { $0.generation <= target }
            waiters.removeAll { $0.generation <= target }
            ready.forEach { $0.continuation.resume(returning: result) }
        }
        workerRunning = false
    }

    private func gate(now: Date, settings: UploadSettings) -> FlushStatus? {
        guard isUploadAllowed() else { return .consentDenied }
        if let until = pausedUntil { if until > now { return .authenticationRequired(until: until) } else { pausedUntil = nil } }
        if let until = backoffUntil { if until > now { return .backingOff(until: until) } else { backoffUntil = nil } }
        let network = connectivity.currentStatus
        guard network.isConnected else { return .offline }
        guard settings.networkPolicy.permits(network) else { return .blockedByNetworkPolicy }
        return nil
    }

    private func performPass() async -> PassResult {
        eventsSinceLastPass = 0
        var acknowledged = 0
        while !Task.isCancelled && !stopped {
            let settings = self.settings.withLock { $0 }
            let now = clock.now()
            if let blocked = gate(now: now, settings: settings) { return PassResult(status: blocked, acknowledged: acknowledged) }
            do {
                _ = try await store.recoverExpiredLeases(now: now)
                let purged = try await store.purgeExpired(createdBefore: now.addingTimeInterval(-configuration.retention))
                if purged > 0 { diagnostics.record(.eventsDropped(.retentionExpired, purged)) }

                let request = LeaseRequest(batchID: makeID(),
                                           maxEvents: min(settings.maxBatchEvents, adaptiveBatchLimit ?? Int.max),
                                           maxBytes: settings.maxBatchBytes,
                                           envelopeOverheadBytes: UploadRequest.envelopeOverhead(projectID: configuration.projectID),
                                           now: now, leaseDuration: configuration.leaseDuration)
                guard let batch = try await store.leaseBatch(request) else {
                    adaptiveBatchLimit = nil
                    await recordGauge()
                    return PassResult(status: .completed, acknowledged: acknowledged)
                }
                let step = await upload(batch, settings: settings)
                acknowledged += step.acknowledged
                if let stop = step.stop { await recordGauge(); return PassResult(status: stop, acknowledged: acknowledged) }
            } catch {
                onError((error as? AnalyticsError) ?? .storageFailure(code: -1))
                return PassResult(status: .storageFailure, acknowledged: acknowledged)
            }
        }
        return PassResult(status: .stopped, acknowledged: acknowledged)
    }

    // MARK: One batch

    private func upload(_ batch: LeasedBatch, settings: UploadSettings) async -> Step {
        let sentAt = clock.now()
        let request = UploadRequest(batchID: batch.id, projectID: configuration.projectID,
                                    sdkVersion: AnalyticsSDKInfo.version, sentAt: sentAt, events: batch.events)
        let result = await transport.send(request)
        let finished = clock.now()
        return await apply(result, to: batch, settings: settings, now: finished, duration: finished.timeIntervalSince(sentAt))
    }

    /// The single place that decides what happens to leased events. Invariant: events are deleted only if
    /// (a) listed in a valid acknowledgment as accepted/duplicate/non-retryably-rejected, (b) a lone event the
    /// server says it cannot accept at all (400/413 on a batch of one), or (c) their counted-attempt budget is spent.
    private func apply(_ result: UploadResult, to batch: LeasedBatch, settings: UploadSettings,
                       now: Date, duration: TimeInterval) async -> Step {
        func metric(_ outcome: UploadOutcome) {
            diagnostics.record(.uploadFinished(outcome: outcome, events: batch.events.count, bytes: batch.totalBytes, duration: duration))
        }

        switch result {
        case .acknowledged(let ack):
            let resolution = ack.resolve(sentEventIDs: Set(batch.events.map(\.eventID)))
            let deletable = resolution.deletable
            var retryAt = now
            if !deletable.isEmpty { consecutiveFailures = 0 }
            if !resolution.retain.isEmpty {
                if deletable.isEmpty { consecutiveFailures += 1 }
                retryAt = now.addingTimeInterval(settings.retry.backoff(forFailureCount: max(1, consecutiveFailures), jitter: random()))
            }
            _ = await resolve(batch, delete: deletable, retryAt: retryAt, countsAttempt: true, settings: settings)
            metric(resolution.retain.isEmpty ? .acknowledged : .partial)

            let ages = batch.events.filter { resolution.confirmed.contains($0.eventID) }.map { now.timeIntervalSince($0.createdAt) }
            if !ages.isEmpty { diagnostics.record(.eventsAcknowledged(count: ages.count, totalAge: ages.reduce(0, +), maxAge: ages.max() ?? 0)) }
            if !resolution.permanentlyRejected.isEmpty { diagnostics.record(.eventsDropped(.permanentlyRejected, resolution.permanentlyRejected.count)) }

            if deletable.isEmpty {   // server confirmed nothing: treat as a failed attempt
                backoffUntil = retryAt
                scheduleWake(after: retryAt.timeIntervalSince(now))
                return Step(acknowledged: 0, stop: .backingOff(until: retryAt))
            }
            // Progress was made, so keep draining; but retained events must not wait for the next interval tick.
            if !resolution.retain.isEmpty { scheduleWake(after: retryAt.timeIntervalSince(now)) }
            return Step(acknowledged: resolution.confirmed.count, stop: nil)

        case .malformedAcknowledgment:
            metric(.malformedAcknowledgment)
            return await transientFailure(batch, settings: settings, now: now, retryAfter: nil, countsAttempt: true)

        case .rateLimited(let retryAfter):
            metric(.rateLimited)
            // Not the events' fault: refund the attempt, honour Retry-After (clamped), apply globally.
            return await transientFailure(batch, settings: settings, now: now, retryAfter: retryAfter, countsAttempt: false)

        case .serverError(_, let retryAfter):
            metric(.serverError)
            return await transientFailure(batch, settings: settings, now: now, retryAfter: retryAfter, countsAttempt: true)

        case .network(let failure):
            switch failure {
            case .offline:
                metric(.offline)
                _ = await resolve(batch, delete: [], retryAt: now, countsAttempt: false, settings: settings)
                return Step(acknowledged: 0, stop: .offline)
            case .cancelled:
                metric(.cancelled)
                _ = await resolve(batch, delete: [], retryAt: now, countsAttempt: false, settings: settings)
                return Step(acknowledged: 0, stop: .stopped)
            case .timeout:
                metric(.timeout)
                return await transientFailure(batch, settings: settings, now: now, retryAfter: nil, countsAttempt: true)
            case .other:
                metric(.networkError)
                return await transientFailure(batch, settings: settings, now: now, retryAfter: nil, countsAttempt: true)
            }

        case .authenticationFailed:
            metric(.authenticationFailed)
            return await pause(batch, settings: settings, now: now, duration: settings.retry.authenticationPause)

        case .configurationError:
            metric(.configurationError)
            return await pause(batch, settings: settings, now: now, duration: settings.retry.configurationPause)

        case .payloadTooLarge, .payloadRejected:
            metric(.payloadRejected)
            if batch.events.count == 1 {
                // A single event the server will never take: dropping it is the only way to unblock the queue.
                _ = await resolve(batch, delete: [batch.events[0].eventID], retryAt: now, countsAttempt: true, settings: settings)
                diagnostics.record(.eventsDropped(.permanentlyRejected, 1))
                return Step(acknowledged: 0, stop: nil)
            }
            // Bisect: halve the batch size until the offending event is isolated. Terminates in log2(n) steps.
            adaptiveBatchLimit = max(1, batch.events.count / 2)
            _ = await resolve(batch, delete: [], retryAt: now, countsAttempt: false, settings: settings)
            return Step(acknowledged: 0, stop: nil)
        }
    }

    private func transientFailure(_ batch: LeasedBatch, settings: UploadSettings, now: Date,
                                  retryAfter: TimeInterval?, countsAttempt: Bool) async -> Step {
        consecutiveFailures += 1
        let computed = settings.retry.backoff(forFailureCount: consecutiveFailures, jitter: random())
        let delay = max(computed, settings.retry.clamp(retryAfter: retryAfter) ?? 0)
        let until = now.addingTimeInterval(delay)
        backoffUntil = until   // global: a struggling server is not retried per-event in parallel
        _ = await resolve(batch, delete: [], retryAt: until, countsAttempt: countsAttempt, settings: settings)
        scheduleWake(after: delay)
        return Step(acknowledged: 0, stop: .backingOff(until: until))
    }

    private func pause(_ batch: LeasedBatch, settings: UploadSettings, now: Date, duration: TimeInterval) async -> Step {
        let until = now.addingTimeInterval(duration)
        pausedUntil = until
        // Events stay eligible immediately: the pause, not the row, gates uploads, so `credentialsDidChange()` can resume at once.
        _ = await resolve(batch, delete: [], retryAt: now, countsAttempt: false, settings: settings)
        scheduleWake(after: duration)
        return Step(acknowledged: 0, stop: .authenticationRequired(until: until))
    }

    private func resolve(_ batch: LeasedBatch, delete: Set<String>, retryAt: Date, countsAttempt: Bool,
                         settings: UploadSettings) async -> ResolutionReport? {
        do {
            let report = try await store.resolve(BatchResolution(batchID: batch.id, deleteEventIDs: delete, retryAt: retryAt,
                                                                 countsAttempt: countsAttempt, maxAttempts: settings.retry.maxAttempts))
            if report.droppedMaxAttempts > 0 { diagnostics.record(.eventsDropped(.maxAttempts, report.droppedMaxAttempts)) }
            if report.released > 0 { diagnostics.record(.retriesScheduled(report.released)) }
            return report
        } catch {
            // Resolution failed: the lease simply expires and `recoverExpiredLeases` returns the events to the queue.
            onError((error as? AnalyticsError) ?? .storageFailure(code: -1))
            return nil
        }
    }

    private func scheduleWake(after delay: TimeInterval) {
        wakeTask?.cancel()
        let clock = self.clock
        wakeTask = Task.detached { [weak self] in
            do { try await clock.sleep(for: delay) } catch { return }
            await self?.requestPass()
        }
    }

    private func recordGauge() async {
        guard let stats = try? await store.stats() else { return }
        let age = stats.oldestEventAt.map { clock.now().timeIntervalSince($0) }
        diagnostics.record(.queueGauge(pending: stats.pendingEvents, payloadBytes: stats.payloadBytes, oldestAge: age))
    }
}
