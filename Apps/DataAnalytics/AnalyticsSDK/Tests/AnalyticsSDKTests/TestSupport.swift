import Foundation
import Testing
@testable import AnalyticsSDK

// MARK: Fakes

/// Deterministic clock. Time moves only when a test calls `advance`; sleepers wake in deadline order.
final class ManualClock: AnalyticsClock, @unchecked Sendable {
    private struct Sleeper { var id: UUID; var deadline: Date; var continuation: CheckedContinuation<Void, Error> }
    private struct State { var now: Date; var sleepers: [Sleeper] = [] }
    private let state: Locked<State>

    init(start: Date = Date(timeIntervalSince1970: 1_800_000_000)) { state = Locked(State(now: start)) }

    func now() -> Date { state.withLock { $0.now } }

    func advance(by interval: TimeInterval) {
        let due = state.withLock { s -> [Sleeper] in
            s.now = s.now.addingTimeInterval(interval)
            let ready = s.sleepers.filter { $0.deadline <= s.now }
            s.sleepers.removeAll { $0.deadline <= s.now }
            return ready
        }
        due.sorted { $0.deadline < $1.deadline }.forEach { $0.continuation.resume() }
    }

    func sleep(for interval: TimeInterval) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
                let action: (() -> Void)? = state.withLock { s in
                    if interval <= 0 { return { c.resume() } }
                    if Task.isCancelled { return { c.resume(throwing: CancellationError()) } }
                    s.sleepers.append(Sleeper(id: id, deadline: s.now.addingTimeInterval(interval), continuation: c))
                    return nil
                }
                action?()
            }
        } onCancel: {
            let sleeper = state.withLock { s -> Sleeper? in
                guard let i = s.sleepers.firstIndex(where: { $0.id == id }) else { return nil }
                return s.sleepers.remove(at: i)
            }
            sleeper?.continuation.resume(throwing: CancellationError())
        }
    }
}

final class FakeConnectivity: ConnectivityMonitor, @unchecked Sendable {
    private let state = Locked<(status: ConnectivityStatus, conts: [UUID: AsyncStream<ConnectivityStatus>.Continuation])>((.wifi, [:]))
    var currentStatus: ConnectivityStatus { state.withLock { $0.status } }
    func set(_ status: ConnectivityStatus) {
        let targets = state.withLock { s -> [AsyncStream<ConnectivityStatus>.Continuation] in s.status = status; return Array(s.conts.values) }
        targets.forEach { $0.yield(status) }
    }
    func updates() -> AsyncStream<ConnectivityStatus> {
        AsyncStream { c in
            let id = UUID()
            state.withLock { $0.conts[id] = c }
            c.onTermination = { [state] _ in state.withLock { $0.conts[id] = nil } }
        }
    }
    func start() {}
    func stop() {}
}

final class FakeTransport: AnalyticsTransport, @unchecked Sendable {
    typealias Handler = @Sendable (UploadRequest) async -> UploadResult
    private let handler = Locked<Handler>({ FakeTransport.ackAll($0) })
    private let recorded = Locked<[UploadRequest]>([])
    private let inFlight = Locked<(current: Int, max: Int)>((0, 0))

    var requests: [UploadRequest] { recorded.withLock { $0 } }
    var maxConcurrentRequests: Int { inFlight.withLock { $0.max } }
    func setHandler(_ h: @escaping Handler) { handler.withLock { $0 = h } }

    func send(_ request: UploadRequest) async -> UploadResult {
        recorded.withLock { $0.append(request) }
        inFlight.withLock { $0.current += 1; $0.max = max($0.max, $0.current) }
        defer { inFlight.withLock { $0.current -= 1 } }
        let h = handler.withLock { $0 }
        return await h(request)
    }

    static func ackAll(_ r: UploadRequest) -> UploadResult {
        .acknowledged(UploadAcknowledgment(batchID: r.batchID, accepted: r.events.map(\.eventID)))
    }
}

/// One-shot async gate used to hold a fake network call open.
actor AsyncGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func open() {
        isOpen = true
        waiters.forEach { $0.resume() }
        waiters = []
    }
}

struct FixedContextProvider: ContextProvider {
    func currentContext() -> EventContext {
        EventContext(appVersion: "1.2.3", appBuild: "42", osName: "iOS", osVersion: "17.0.0", deviceModel: "iPhone15,2",
                     locale: "en_US", timeZone: "UTC", networkType: "wifi", sdkVersion: AnalyticsSDKInfo.version)
    }
}

// MARK: Harness

final class Harness: @unchecked Sendable {
    let directory: URL
    let clock = ManualClock()
    let transport = FakeTransport()
    let connectivity = FakeConnectivity()
    private let counter = Locked(0)

    init() {
        // Honour $TMPDIR explicitly: Foundation's temporaryDirectory ignores it on Darwin, which breaks sandboxed CI.
        let base = ProcessInfo.processInfo.environment["TMPDIR"].map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? FileManager.default.temporaryDirectory
        directory = base.appendingPathComponent("analytics-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    var databaseURL: URL { directory.appendingPathComponent("events.sqlite") }
    func cleanUp() { try? FileManager.default.removeItem(at: directory) }

    func configuration(_ mutate: (inout AnalyticsConfiguration) -> Void = { _ in }) -> AnalyticsConfiguration {
        var c = AnalyticsConfiguration(projectID: "test-project", endpoint: URL(string: "https://example.test/v1/analytics/events")!)
        c.storage.databaseURL = databaseURL
        c.initialConsent = .granted
        c.observesAppLifecycle = false
        c.upload.uploadInterval = 3600
        mutate(&c)
        return c
    }

    var dependencies: AnalyticsDependencies {
        let counter = self.counter
        let transport = self.transport
        return AnalyticsDependencies(
            clock: clock, connectivity: connectivity,
            makeStore: { c, rebuilt in try SQLiteEventStore(url: c.resolvedDatabaseURL, onRebuild: rebuilt) },
            makeTransport: { _, _, _ in transport },
            makeContextProvider: { _ in FixedContextProvider() },
            makeID: { counter.withLock { $0 += 1; return "id-\($0)" } },
            random: { 0.5 },                      // jitter fixed at the midpoint → deterministic backoff
            backgroundRunner: ImmediateBackgroundRunner())
    }

    /// A fresh SDK over the *same* database file: this is how "app restart" is simulated.
    func makeSDK(_ mutate: (inout AnalyticsConfiguration) -> Void = { _ in }) async throws -> AnalyticsSDK {
        let sdk = AnalyticsSDK(configuration: configuration(mutate), dependencies: dependencies)
        try await sdk.initialize()
        return sdk
    }

    func openStore() throws -> SQLiteEventStore { try SQLiteEventStore(url: databaseURL) }
}

// MARK: Helpers

func decodeEvents(_ request: UploadRequest) throws -> [AnalyticsEvent] {
    let decoder = WireFormat.makeDecoder()
    return try request.events.map { try decoder.decode(AnalyticsEvent.self, from: $0.payload) }
}

/// Polls for an asynchronous condition without sleeping a fixed time.
func eventually(timeout: TimeInterval = 5, _ condition: @Sendable () async -> Bool) async {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if await condition() { return }
        try? await Task.sleep(nanoseconds: 5_000_000)
    }
    Issue.record("condition not met within \(timeout)s")
}

func makeEvent(_ id: String, bytes: Int = 100, at date: Date = Date(timeIntervalSince1970: 1_800_000_000)) -> PersistableEvent {
    PersistableEvent(eventID: id, createdAt: date, payload: Data(repeating: 0x61, count: bytes))
}

let roomyLimits = StorageLimits(maxEvents: 100_000, maxBytes: 100_000_000, fullPolicy: .rejectNew)

/// Records a test failure; returns Void so it can be used as `return fail("...")`.
func fail(_ message: String) { Issue.record(Comment(rawValue: message)) }
