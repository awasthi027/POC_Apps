import Foundation

/// Retry and pause behaviour. All delays are computed, never slept, here; the coordinator sleeps through the
/// injected clock so tests can advance time instantly.
public struct RetryPolicy: Sendable, Equatable {
    public var baseDelay: TimeInterval = 5
    public var multiplier: Double = 2
    public var maxDelay: TimeInterval = 15 * 60
    /// Per-event budget of *counted* attempts (timeouts, 5xx, malformed acks, unconfirmed events). Offline
    /// failures, 429s and auth pauses are not counted because the event did nothing wrong. After the budget
    /// is spent the event is dropped and reported, so a poison event cannot be retried forever.
    public var maxAttempts = 8
    /// Upper bound applied to a server-provided `Retry-After`, so a bad header cannot park uploads for days.
    public var maxRetryAfter: TimeInterval = 3600
    /// Pause after 401 that survived a credential refresh.
    public var authenticationPause: TimeInterval = 15 * 60
    /// Pause after 403 / unexpected 4xx (misconfiguration; hammering will not help).
    public var configurationPause: TimeInterval = 60 * 60

    public init() {}

    /// Exponential backoff with "equal jitter": half deterministic, half random. `jitter` is in 0...1.
    /// The deterministic half guarantees a minimum spacing; the random half de-synchronises a fleet of
    /// devices that all failed at the same moment (retry-storm protection).
    public func backoff(forFailureCount failures: Int, jitter: Double) -> TimeInterval {
        let exponent = Double(max(0, failures - 1))
        let ceiling = min(maxDelay, baseDelay * pow(multiplier, exponent))
        let j = min(1, max(0, jitter))
        return ceiling / 2 + (ceiling / 2) * j
    }

    func clamp(retryAfter: TimeInterval?) -> TimeInterval? {
        retryAfter.map { min(max(0, $0), maxRetryAfter) }
    }
}

enum RetryAfter {
    /// Parses delta-seconds or an HTTP-date. Invalid / negative values yield nil (caller falls back to backoff).
    static func parse(_ header: String?, now: Date) -> TimeInterval? {
        guard let raw = header?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return nil }
        if let seconds = Int(raw) { return seconds >= 0 ? TimeInterval(seconds) : nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        guard let date = formatter.date(from: raw) else { return nil }
        return max(0, date.timeIntervalSince(now))
    }
}
