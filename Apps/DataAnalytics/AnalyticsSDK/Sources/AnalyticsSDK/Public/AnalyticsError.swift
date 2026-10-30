import Foundation

public enum ValidationFailure: String, Sendable, Equatable {
    case invalidName
    case reservedName
    case tooManyProperties
    case invalidPropertyKey
    case reservedPropertyKey
    case stringValueTooLong
    case nonFiniteNumber
    case possiblePII
    case eventTooLarge
    case invalidUserID
}

/// Every error the SDK surfaces. Cases carry codes and property *keys* only — never property values, user
/// IDs or tokens — so errors are safe to log.
public enum AnalyticsError: Error, Sendable, Equatable {
    /// `initialize()` has not completed (or failed). Nothing was recorded.
    case notInitialized
    case shutDown
    case invalidConfiguration(String)
    /// The event was rejected by validation. Nothing was recorded.
    case validation(ValidationFailure, key: String?)
    /// Consent is denied (or was revoked while the event was buffered). Nothing was recorded.
    case consentDenied
    /// The bounded in-memory ingress buffer is full. Nothing was recorded; the caller may retry later.
    case backpressure
    /// The durable queue is at its configured limit and the policy is `.rejectNew` (or nothing is evictable).
    case storageFull
    /// The device disk is full (SQLITE_FULL).
    case diskFull
    /// The database file was corrupt and has been replaced; previously queued events were lost.
    case storageCorrupted
    case incompatibleDatabase(found: Int, supported: Int)
    case storageFailure(code: Int32)
}

public enum TrackOutcome: Sendable, Equatable {
    /// The SQLite transaction containing the event committed. `eventID` is the stable ID used on every retry.
    case persisted(eventID: String)
    /// Consent is not granted; the event was intentionally not recorded.
    case droppedNoConsent
}

public enum EnqueueResult: Sendable, Equatable {
    /// Accepted into the bounded in-memory buffer. NOT yet durable; a later persistence failure is reported
    /// through `AnalyticsConfiguration.onError` and diagnostics.
    case accepted(eventID: String)
    case droppedNoConsent
    case rejected(AnalyticsError)
}

public enum ConsentState: String, Sendable, Codable, Equatable {
    case granted
    case denied
}
