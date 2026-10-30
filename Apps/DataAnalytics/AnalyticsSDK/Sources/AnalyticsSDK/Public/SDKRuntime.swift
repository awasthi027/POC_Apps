import Foundation

/// Everything the SDK needs at construction time, injectable for tests. `live()` wires production defaults.
struct AnalyticsDependencies: Sendable {
    var clock: any AnalyticsClock
    var connectivity: any ConnectivityMonitor
    var makeStore: @Sendable (AnalyticsConfiguration, @escaping @Sendable () -> Void) throws -> any EventStore
    var makeTransport: @Sendable (AnalyticsConfiguration, any AnalyticsClock, Locked<UploadSettings>) -> any AnalyticsTransport
    var makeContextProvider: @Sendable (any ConnectivityMonitor) -> any ContextProvider
    var makeID: @Sendable () -> String
    var random: @Sendable () -> Double
    var backgroundRunner: any BackgroundTaskRunner

    static func live() -> AnalyticsDependencies {
        #if canImport(UIKit) && !os(watchOS)
        let runner: any BackgroundTaskRunner = UIKitBackgroundRunner()
        #else
        let runner: any BackgroundTaskRunner = ImmediateBackgroundRunner()
        #endif
        return AnalyticsDependencies(
            clock: SystemClock(),
            connectivity: PathMonitorConnectivity(),
            makeStore: { configuration, onRebuild in
                try SQLiteEventStore(url: configuration.resolvedDatabaseURL, onRebuild: onRebuild)
            },
            makeTransport: { configuration, clock, settings in
                URLSessionTransport(endpoint: configuration.endpoint, credentials: configuration.credentials,
                                    session: URLSessionTransport.makeSession(timeout: configuration.requestTimeout),
                                    timeout: configuration.requestTimeout, clock: clock,
                                    networkPolicy: { settings.withLock { $0.networkPolicy } })
            },
            makeContextProvider: { DefaultContextProvider(connectivity: $0) },
            makeID: { UUID().uuidString.lowercased() },
            random: { Double.random(in: 0...1) },
            backgroundRunner: runner)
    }
}

/// The wired-up object graph, created once by `initialize()`. Also hosts the event *builders*, which run
/// under the ingress lock: they must be synchronous, allocation-light and must never suspend.
final class SDKRuntime: @unchecked Sendable {
    let configuration: AnalyticsConfiguration
    let clock: any AnalyticsClock
    let store: any EventStore
    let connectivity: any ConnectivityMonitor
    let ingress: EventIngress
    let processor: EventProcessor
    let sessions: SessionManager
    let identity: IdentityManager
    let consent: ConsentManager
    let coordinator: UploadCoordinator
    let settings: Locked<UploadSettings>
    let diagnostics: DiagnosticsAggregator
    let makeID: @Sendable () -> String
    let observers = Locked<[NSObjectProtocol]>([])
    let flushRequested = Locked<Bool>(false)

    init(configuration: AnalyticsConfiguration, clock: any AnalyticsClock, store: any EventStore,
         connectivity: any ConnectivityMonitor, ingress: EventIngress, processor: EventProcessor,
         sessions: SessionManager, identity: IdentityManager, consent: ConsentManager,
         coordinator: UploadCoordinator, settings: Locked<UploadSettings>, diagnostics: DiagnosticsAggregator,
         makeID: @escaping @Sendable () -> String) {
        self.configuration = configuration; self.clock = clock; self.store = store; self.connectivity = connectivity
        self.ingress = ingress; self.processor = processor; self.sessions = sessions; self.identity = identity
        self.consent = consent; self.coordinator = coordinator; self.settings = settings
        self.diagnostics = diagnostics; self.makeID = makeID
    }

    private func fail(_ error: Error) -> EventIngress.Built { ([], .failed(error as? AnalyticsError ?? .storageFailure(code: -1))) }

    // MARK: Builders (run under the ingress lock)

    func buildTrack(eventID: String, name: String, properties: [String: AnalyticsValue],
                    completion: EventIngress.Completion?) -> EventIngress.Built {
        guard consent.isGranted else { return ([], .noConsent) }
        do { try processor.validate(name: name, properties: properties, allowReservedName: false) } catch { return fail(error) }
        return finish(eventID: eventID, name: name, properties: properties, leading: [], completion: completion)
    }

    func buildScreen(eventID: String, screenName: String, properties: [String: AnalyticsValue],
                     completion: EventIngress.Completion?) -> EventIngress.Built {
        guard consent.isGranted else { return ([], .noConsent) }
        do { try processor.validate(name: screenName, properties: properties, allowReservedName: false) } catch { return fail(error) }
        var merged = properties
        merged["screen_name"] = .string(screenName)
        return finish(eventID: eventID, name: "$screen_view", properties: merged, leading: [], completion: completion)
    }

    /// Identity semantics: events already queued keep the identity they were created with. Switching from user A
    /// to user B ends A's session (stamped with A's identity), rotates the anonymous ID, and only then starts B's.
    func buildIdentify(eventID: String, userID: String, properties: [String: AnalyticsValue],
                       completion: EventIngress.Completion?) -> EventIngress.Built {
        guard consent.isGranted else { return ([], .noConsent) }
        do {
            try processor.validate(userID: userID)
            try processor.validate(name: "$identify", properties: properties, allowReservedName: true)
        } catch { return fail(error) }

        let now = clock.now()
        let before = identity.snapshot()
        var leading: [EventIngress.Item] = []
        if let previous = before.userID, previous != userID {
            leading += sessionItems(sessions.end(now: now, reason: .identityChanged), identity: before)
            identity.reset(newAnonymousID: makeID())
        }
        identity.setUser(userID)
        return finish(eventID: eventID, name: "$identify", properties: properties, leading: leading, completion: completion)
    }

    /// Logout. Always honoured, even without consent: forgetting identity is never privacy-negative.
    func buildReset(completion: EventIngress.Completion?) -> EventIngress.Built {
        let now = clock.now()
        let before = identity.snapshot()
        let transitions = sessions.end(now: now, reason: .explicit)
        var items = consent.isGranted ? sessionItems(transitions, identity: before) : []
        identity.reset(newAnonymousID: makeID())
        items.append(EventIngress.Item(event: nil, completion: completion))   // barrier: persists the new identity
        return (items, .queued)
    }

    func buildEndSession(completion: EventIngress.Completion?) -> EventIngress.Built {
        guard consent.isGranted else { return ([], .noConsent) }
        let items = sessionItems(sessions.end(now: clock.now(), reason: .explicit), identity: identity.snapshot())
        return (items + [EventIngress.Item(event: nil, completion: completion)], .queued)
    }

    /// App became active: counts as activity, may roll the session over.
    func buildLifecycleTouch() -> EventIngress.Built {
        guard consent.isGranted else { return ([], .noConsent) }
        let (_, transitions) = sessions.touch(now: clock.now())
        return (sessionItems(transitions, identity: identity.snapshot()), .queued)
    }

    private func finish(eventID: String, name: String, properties: [String: AnalyticsValue],
                        leading: [EventIngress.Item], completion: EventIngress.Completion?) -> EventIngress.Built {
        let now = clock.now()
        let ident = identity.snapshot()
        let (sessionID, transitions) = sessions.touch(now: now)
        var items = leading + sessionItems(transitions, identity: ident)
        do {
            let event = try processor.makeEvent(eventID: eventID, name: name, properties: properties, timestamp: now,
                                                sessionID: sessionID, identity: ident)
            items.append(EventIngress.Item(event: event, completion: completion))
            return (items, .queued)
        } catch {
            // Session transitions were already consumed from the manager; still emit them so none is lost.
            return (items, .failed((error as? AnalyticsError) ?? .storageFailure(code: -1)))
        }
    }

    private func sessionItems(_ transitions: [SessionManager.Transition], identity: IdentitySnapshot) -> [EventIngress.Item] {
        transitions.compactMap { transition in
            let built: PersistableEvent?
            switch transition {
            case .ended(let state, let reason, let at):
                let duration = Int(max(0, at.timeIntervalSince(state.startedAt)) * 1000)
                built = try? processor.makeEvent(eventID: makeID(), name: "$session_end",
                                                 properties: ["session_duration_ms": .int(duration), "reason": .string(reason.rawValue)],
                                                 timestamp: at, sessionID: state.id, identity: identity)
            case .started(let state):
                built = try? processor.makeEvent(eventID: makeID(), name: "$session_start", properties: [:],
                                                 timestamp: state.startedAt, sessionID: state.id, identity: identity)
            }
            return built.map { EventIngress.Item(event: $0, completion: nil) }
        }
    }
}
