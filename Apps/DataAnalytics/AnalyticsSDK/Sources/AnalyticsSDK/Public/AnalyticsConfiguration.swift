import Foundation

public enum NetworkPolicy: Sendable, Equatable {
    /// Upload on any connected interface.
    case any
    /// Upload only on unmetered, unconstrained paths (no cellular, no Personal Hotspot, no Low Data Mode).
    case unmeteredOnly

    func permits(_ status: ConnectivityStatus) -> Bool {
        guard status.isConnected else { return false }
        switch self {
        case .any: return true
        case .unmeteredOnly: return !status.isExpensive && !status.isConstrained
        }
    }
}

public enum StorageFullPolicy: Sendable, Equatable {
    /// Evict the oldest events that are not currently leased to make room. Evictions are counted in diagnostics.
    case dropOldest
    /// Refuse new events with `AnalyticsError.storageFull`; queued events are preserved.
    case rejectNew
}

public enum ConsentRevocationPolicy: Sendable, Equatable {
    /// Delete every queued event (default; the conservative choice).
    case deleteQueuedEvents
    /// Keep queued events on disk but never upload them unless consent is granted again.
    case retainQueuedEvents
}

public enum PIIPolicy: Sendable, Equatable {
    /// Reject properties whose key or value looks like a credential, card number or e-mail address. Heuristic.
    case rejectSuspected
    case off
}

/// Settings that can change at runtime via `AnalyticsSDK.updateUploadSettings`. A batch uses the snapshot
/// taken when it was leased.
public struct UploadSettings: Sendable, Equatable {
    public var maxBatchEvents = 50
    public var maxBatchBytes = 256 * 1024
    /// Best-effort. Fires only while the process is running; never while suspended.
    public var uploadInterval: TimeInterval = 30
    public var networkPolicy: NetworkPolicy = .any
    public var retry = RetryPolicy()

    public init() {}
}

public struct EventLimits: Sendable, Equatable {
    public var maxEventBytes = 16 * 1024
    public var maxProperties = 50
    public var maxNameLength = 64
    public var maxKeyLength = 64
    public var maxStringValueBytes = 1024

    public init() {}
}

public struct StorageConfiguration: Sendable, Equatable {
    /// `nil` → `Application Support/AnalyticsSDK/<project>/events.sqlite`, one file per project.
    public var databaseURL: URL?
    public var maxQueuedEvents = 10_000
    /// Bound on summed event payload bytes (the practical proxy for disk use; WAL/page overhead is extra).
    public var maxQueuedBytes = 10 * 1024 * 1024
    public var retention: TimeInterval = 7 * 24 * 3600
    public var fullPolicy: StorageFullPolicy = .dropOldest
    /// A lease not resolved within this window is considered abandoned (process died mid-upload).
    public var leaseDuration: TimeInterval = 300

    public init() {}
}

public struct AnalyticsConfiguration: Sendable {
    public var projectID: String
    public var endpoint: URL
    public var credentials: any CredentialProvider

    public var upload = UploadSettings()
    public var limits = EventLimits()
    public var storage = StorageConfiguration()

    /// Capacity of the in-memory ingress buffer between callers and the database writer. Beyond this,
    /// `enqueue` returns `.rejected(.backpressure)` and `track` throws it.
    public var ingressCapacity = 2_000
    public var requestTimeout: TimeInterval = 30
    public var sessionTimeout: TimeInterval = 30 * 60

    /// Used until the host calls `setConsent`. Conservative default: opt-in.
    public var initialConsent: ConsentState = .denied
    public var consentRevocation: ConsentRevocationPolicy = .deleteQueuedEvents
    public var piiPolicy: PIIPolicy = .rejectSuspected
    /// Observe UIApplication notifications by name (no UIKit import). Disable for extensions.
    public var observesAppLifecycle = true

    /// Called for asynchronous failures that no caller is awaiting (e.g. a fire-and-forget `enqueue` that
    /// later fails to persist). Carries no payload data.
    public var onError: (@Sendable (AnalyticsError) -> Void)?
    public var metricsSink: (any AnalyticsMetricsSink)?

    public init(projectID: String, endpoint: URL, credentials: any CredentialProvider = StaticCredentialProvider(token: nil)) {
        self.projectID = projectID
        self.endpoint = endpoint
        self.credentials = credentials
    }

    func validate() throws {
        func fail(_ m: String) -> AnalyticsError { .invalidConfiguration(m) }
        guard !projectID.isEmpty else { throw fail("projectID is empty") }
        guard let scheme = endpoint.scheme?.lowercased(), let host = endpoint.host else { throw fail("endpoint must be an absolute URL") }
        guard scheme == "https" || ["localhost", "127.0.0.1", "::1"].contains(host) else { throw fail("endpoint must use https") }
        guard limits.maxEventBytes > 0, limits.maxProperties > 0, limits.maxNameLength > 0 else { throw fail("invalid event limits") }
        try upload.validate(limits: limits, projectID: projectID)
        guard storage.maxQueuedEvents > 0, storage.maxQueuedBytes >= limits.maxEventBytes else { throw fail("storage limits too small") }
        guard storage.retention > 0, storage.leaseDuration > 0 else { throw fail("retention/lease must be positive") }
        guard ingressCapacity >= 8 else { throw fail("ingressCapacity too small") }
        guard sessionTimeout > 0, requestTimeout > 0 else { throw fail("timeouts must be positive") }
    }

    var resolvedDatabaseURL: URL {
        if let url = storage.databaseURL { return url }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let name = projectID.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "default"
        return base.appendingPathComponent("AnalyticsSDK/\(name)/events.sqlite")
    }
}

extension UploadSettings {
    func validate(limits: EventLimits, projectID: String) throws {
        guard (1...500).contains(maxBatchEvents) else { throw AnalyticsError.invalidConfiguration("maxBatchEvents must be 1...500") }
        let overhead = UploadRequest.envelopeOverhead(projectID: projectID)
        guard maxBatchBytes >= limits.maxEventBytes + overhead else {
            throw AnalyticsError.invalidConfiguration("maxBatchBytes must fit one maximum-size event plus envelope")
        }
        guard uploadInterval >= 1 else { throw AnalyticsError.invalidConfiguration("uploadInterval must be >= 1s") }
        guard retry.maxAttempts >= 1, retry.baseDelay > 0, retry.maxDelay >= retry.baseDelay else {
            throw AnalyticsError.invalidConfiguration("invalid retry policy")
        }
    }
}
