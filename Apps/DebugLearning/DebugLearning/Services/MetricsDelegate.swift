//
//  MetricsDelegate.swift
//  DebugLearning
//
//  Captures per-transaction URLSessionTaskMetrics (DNS, connect, TLS, TTFB, total)
//  for any request made through a URLSession configured with this delegate.
//

import Foundation
import os

private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "DebugLearning", category: "NetworkMetrics")

/// Collects timing metrics for every task run on a URLSession that uses this delegate.
final class MetricsDelegate: NSObject, URLSessionTaskDelegate {

    /// Called on the delegate queue whenever metrics for a task are ready.
    /// Use this to surface metrics to the UI without touching the logger directly.
    var onMetrics: ((NetworkMetricsSummary) -> Void)?

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didFinishCollecting metrics: URLSessionTaskMetrics) {
        guard let t = metrics.transactionMetrics.first else { return }

        let host = task.originalRequest?.url?.host ?? "-"

        func duration(_ start: Date?, _ end: Date?) -> TimeInterval? {
            guard let start, let end else { return nil }
            return end.timeIntervalSince(start)
        }

        let dns = duration(t.domainLookupStartDate, t.domainLookupEndDate)
        let connect = duration(t.connectStartDate, t.connectEndDate)
        let tls = duration(t.secureConnectionStartDate, t.secureConnectionEndDate)
        let ttfb = duration(t.requestStartDate, t.responseStartDate)
        let total = duration(t.fetchStartDate, t.responseEndDate) ?? metrics.taskInterval.duration

        log.debug("host=\(host, privacy: .private) dns=\(dns ?? -1, format: .fixed(precision: 4)) connect=\(connect ?? -1, format: .fixed(precision: 4)) tls=\(tls ?? -1, format: .fixed(precision: 4)) ttfb=\(ttfb ?? -1, format: .fixed(precision: 4)) total=\(total, format: .fixed(precision: 4))")

        let summary = NetworkMetricsSummary(
            host: host,
            dns: dns,
            connect: connect,
            tls: tls,
            timeToFirstByte: ttfb,
            total: total,
            protocolName: t.networkProtocolName,
            isReusedConnection: t.isReusedConnection
        )

        onMetrics?(summary)
    }
}
