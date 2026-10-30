import Foundation

/// Bounded in-memory buffer between callers and the database writer ("group commit").
///
/// Why it exists: calling an actor/transaction per event from thousands of concurrent callers would create
/// thousands of suspended tasks and thousands of single-row transactions. Instead callers append to a bounded
/// array under a short lock, and **one** drain task commits up to `maxGroup` events per transaction.
///
///  * Bounded: beyond `capacity`, `submit` refuses with `.backpressure` (never grows without limit).
///  * Not a source of truth: durability is only claimed once `Item.completion` fires with success, which
///    happens strictly after the SQLite COMMIT.
///  * Ordered: the build closure runs under the lock, so session transitions, identity snapshots, timestamps
///    and arrival order are mutually consistent.
final class EventIngress: @unchecked Sendable {
    typealias Completion = @Sendable (Result<Void, AnalyticsError>) -> Void

    /// `event == nil` is a barrier: it carries a completion and/or triggers a metadata-only commit.
    struct Item {
        var event: PersistableEvent?
        var completion: Completion?
    }

    enum BuildOutcome {
        case queued
        case noConsent
        case failed(AnalyticsError)
    }

    typealias Built = (items: [Item], outcome: BuildOutcome)

    private struct State {
        var buffer: [Item] = []
        var draining = false
        var closed = false
        var idleWaiters: [CheckedContinuation<Void, Never>] = []
    }

    private let state = Locked(State())
    private let store: any EventStore
    private let capacity: Int
    private let maxGroup: Int
    private let limits: StorageLimits
    private let metadataSource: @Sendable () -> [MetadataWrite]
    private let metadataRestore: @Sendable () -> Void
    private let diagnostics: DiagnosticsAggregator
    private let onCommitted: @Sendable (Int) -> Void
    private let onError: @Sendable (AnalyticsError) -> Void

    init(store: any EventStore, capacity: Int, maxGroup: Int = 200, limits: StorageLimits,
         metadataSource: @escaping @Sendable () -> [MetadataWrite], metadataRestore: @escaping @Sendable () -> Void,
         diagnostics: DiagnosticsAggregator, onCommitted: @escaping @Sendable (Int) -> Void,
         onError: @escaping @Sendable (AnalyticsError) -> Void) {
        self.store = store; self.capacity = capacity; self.maxGroup = maxGroup; self.limits = limits
        self.metadataSource = metadataSource; self.metadataRestore = metadataRestore
        self.diagnostics = diagnostics; self.onCommitted = onCommitted; self.onError = onError
    }

    /// Runs `build` under the lock and appends its items. A single submit adds at most three events (session
    /// end, session start, the event itself), so the capacity check reserves room for them up front; that
    /// way a refused call has changed no session/identity state.
    func submit(bypassCapacity: Bool = false, _ build: () -> Built) -> BuildOutcome {
        var startDrain = false
        let outcome: BuildOutcome = state.withLock { s in
            guard !s.closed else { return .failed(.shutDown) }
            guard bypassCapacity || s.buffer.count + 3 <= capacity else { return .failed(.backpressure) }
            let built = build()
            s.buffer.append(contentsOf: built.items)
            if !s.draining && !s.buffer.isEmpty { s.draining = true; startDrain = true }
            return built.outcome
        }
        if startDrain { Task { await self.drainLoop() } }
        return outcome
    }

    /// Resolves after every item submitted before this call has been committed (or has failed).
    func barrier() async throws {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            let outcome = submit(bypassCapacity: true) {
                ([Item(event: nil, completion: { c.resume(with: $0.mapError { $0 as Error }) })], .queued)
            }
            if case .failed(let error) = outcome { c.resume(throwing: error) }
        }
    }

    /// Runs `body` under the ingress lock and, if `error` is non-nil, discards everything still buffered
    /// (failing those items' completions). Used to flip consent so no event can slip in around the flip.
    func atomically<T>(discarding error: AnalyticsError?, _ body: () -> T) -> T {
        var discarded: [Item] = []
        let result = state.withLock { s -> T in
            let r = body()
            if error != nil { discarded = s.buffer; s.buffer = [] }
            return r
        }
        if let error { discarded.forEach { $0.completion?(.failure(error)) } }
        return result
    }

    /// Resolves once no drain is in progress (the in-flight group, if any, has finished committing).
    func waitUntilIdle() async {
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            let idle = state.withLock { s -> Bool in
                if !s.draining { return true }
                s.idleWaiters.append(c)
                return false
            }
            if idle { c.resume() }
        }
    }

    func close() {
        let leftover = state.withLock { s -> [Item] in
            s.closed = true
            defer { s.buffer = [] }
            return s.buffer
        }
        leftover.forEach { $0.completion?(.failure(.shutDown)) }
    }

    // MARK: Drain

    private func drainLoop() async {
        while true {
            let (group, waiters) = state.withLock { s -> ([Item]?, [CheckedContinuation<Void, Never>]) in
                if s.buffer.isEmpty {
                    s.draining = false
                    let w = s.idleWaiters
                    s.idleWaiters = []
                    return (nil, w)
                }
                let n = min(maxGroup, s.buffer.count)
                let group = Array(s.buffer.prefix(n))
                s.buffer.removeFirst(n)
                return (group, [])
            }
            guard let group else { waiters.forEach { $0.resume() }; return }
            await commit(group)
        }
    }

    private func commit(_ group: [Item]) async {
        let events = group.compactMap(\.event)
        let metadata = metadataSource()
        do {
            let report: InsertReport
            if events.isEmpty && metadata.isEmpty { report = InsertReport(outcomes: [], evicted: 0) }
            else { report = try await store.insert(events, metadata: metadata, limits: limits) }

            var next = 0, stored = 0, refused = 0
            for item in group {
                guard item.event != nil else { item.completion?(.success(())); continue }
                switch report.outcomes[next] {
                case .stored: stored += 1; item.completion?(.success(()))
                case .duplicate: item.completion?(.success(()))
                case .rejectedStorageFull:
                    refused += 1
                    item.completion?(.failure(.storageFull))
                    if item.completion == nil { onError(.storageFull) }
                }
                next += 1
            }
            if report.evicted > 0 { diagnostics.record(.eventsDropped(.evictedForSpace, report.evicted)) }
            if refused > 0 { diagnostics.record(.eventsDropped(.storageFull, refused)) }
            if stored > 0 { diagnostics.record(.eventsPersisted(stored)); onCommitted(stored) }
        } catch {
            // Rolled back as a unit: nothing in this group is durable. Say so; never report success.
            metadataRestore()
            let failure = (error as? AnalyticsError) ?? .storageFailure(code: -1)
            diagnostics.record(.eventsDropped(.persistenceFailed, events.count))
            group.forEach { $0.completion?(.failure(failure)) }
            onError(failure)
        }
    }
}
