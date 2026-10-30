import Foundation
import os

public enum DropReason: String, Sendable, CaseIterable {
    case backpressure          // in-memory ingress buffer full
    case storageFull           // queue at limit, new event refused
    case evictedForSpace       // oldest event evicted to admit a newer one
    case retentionExpired
    case maxAttempts           // retry budget exhausted
    case permanentlyRejected   // server said non-retryable
    case consentRevoked
    case persistenceFailed
}

public enum UploadOutcome: String, Sendable {
    case acknowledged, partial, malformedAcknowledgment, rateLimited, serverError
    case authenticationFailed, configurationError, payloadRejected, offline, timeout, networkError, cancelled
}

/// Metrics carry counts, durations and reason codes only. Never event names, properties, IDs of users, or tokens.
public enum AnalyticsMetric: Sendable {
    case trackLatency(TimeInterval)
    case eventsPersisted(Int)
    case eventsDropped(DropReason, Int)
    case uploadFinished(outcome: UploadOutcome, events: Int, bytes: Int, duration: TimeInterval)
    /// `maxAge`/`totalAge`: creation → acknowledgment latency across the acknowledged events of one batch.
    case eventsAcknowledged(count: Int, totalAge: TimeInterval, maxAge: TimeInterval)
    case retriesScheduled(Int)
    case queueGauge(pending: Int, payloadBytes: Int, oldestAge: TimeInterval?)
    case databaseRebuilt
}

public protocol AnalyticsMetricsSink: Sendable {
    func record(_ metric: AnalyticsMetric)
}

public struct AnalyticsDiagnosticsSnapshot: Sendable, Equatable {
    public var pendingEvents = 0
    public var leasedEvents = 0
    public var queuePayloadBytes = 0
    public var databaseDiskBytes = 0
    public var oldestEventAge: TimeInterval?

    public var eventsPersisted = 0
    public var uploadsAttempted = 0
    public var uploadsSucceeded = 0
    public var eventsAcknowledged = 0
    public var retriesScheduled = 0
    public var databaseRebuilds = 0
    public var dropped: [DropReason: Int] = [:]
    public var lastUploadOutcome: UploadOutcome?

    public var averageUploadDuration: TimeInterval?
    public var averageBatchSize: Double?
    public var averageTimeToAcknowledge: TimeInterval?
    public var maxTimeToAcknowledge: TimeInterval?
    public var averageTrackLatency: TimeInterval?

    public var uploadsPausedUntil: Date?
    public var backingOffUntil: Date?
    public var consent: ConsentState = .denied

    public var uploadSuccessRate: Double? { uploadsAttempted == 0 ? nil : Double(uploadsSucceeded) / Double(uploadsAttempted) }
    public var totalDropped: Int { dropped.values.reduce(0, +) }
}

/// Thread-safe aggregation of metrics. Also the single place that logs, and it logs only reason codes and counts.
final class DiagnosticsAggregator: AnalyticsMetricsSink, @unchecked Sendable {
    private struct Totals {
        var snapshot = AnalyticsDiagnosticsSnapshot()
        var uploadDurationSum: TimeInterval = 0, uploadBatches = 0, batchEventsSum = 0
        var ackAgeSum: TimeInterval = 0, ackAgeCount = 0
        var trackLatencySum: TimeInterval = 0, trackCount = 0
    }

    private let totals = Locked(Totals())
    private let forward: (any AnalyticsMetricsSink)?
    private let logger = Logger(subsystem: "com.example.analyticssdk", category: "diagnostics")

    init(forwardingTo sink: (any AnalyticsMetricsSink)?) { forward = sink }

    func record(_ metric: AnalyticsMetric) {
        totals.withLock { t in
            switch metric {
            case .trackLatency(let s): t.trackLatencySum += s; t.trackCount += 1
            case .eventsPersisted(let n): t.snapshot.eventsPersisted += n
            case .eventsDropped(let reason, let n): t.snapshot.dropped[reason, default: 0] += n
            case .uploadFinished(let outcome, let events, _, let duration):
                t.snapshot.uploadsAttempted += 1
                if outcome == .acknowledged { t.snapshot.uploadsSucceeded += 1 }
                t.snapshot.lastUploadOutcome = outcome
                t.uploadDurationSum += duration; t.uploadBatches += 1; t.batchEventsSum += events
            case .eventsAcknowledged(let count, let total, let maxAge):
                t.snapshot.eventsAcknowledged += count
                t.ackAgeSum += total; t.ackAgeCount += count
                t.snapshot.maxTimeToAcknowledge = max(t.snapshot.maxTimeToAcknowledge ?? 0, maxAge)
            case .retriesScheduled(let n): t.snapshot.retriesScheduled += n
            case .queueGauge(let pending, let bytes, let age):
                t.snapshot.pendingEvents = pending; t.snapshot.queuePayloadBytes = bytes; t.snapshot.oldestEventAge = age
            case .databaseRebuilt: t.snapshot.databaseRebuilds += 1
            }
        }
        switch metric {
        case .uploadFinished(let outcome, let events, let bytes, _):
            logger.debug("upload outcome=\(outcome.rawValue, privacy: .public) events=\(events) bytes=\(bytes)")
        case .eventsDropped(let reason, let n):
            logger.notice("dropped reason=\(reason.rawValue, privacy: .public) count=\(n)")
        case .databaseRebuilt:
            logger.error("database rebuilt after corruption")
        default: break
        }
        forward?.record(metric)
    }

    func snapshot() -> AnalyticsDiagnosticsSnapshot {
        totals.withLock { t in
            var s = t.snapshot
            if t.uploadBatches > 0 {
                s.averageUploadDuration = t.uploadDurationSum / Double(t.uploadBatches)
                s.averageBatchSize = Double(t.batchEventsSum) / Double(t.uploadBatches)
            }
            if t.ackAgeCount > 0 { s.averageTimeToAcknowledge = t.ackAgeSum / Double(t.ackAgeCount) }
            if t.trackCount > 0 { s.averageTrackLatency = t.trackLatencySum / Double(t.trackCount) }
            return s
        }
    }
}
