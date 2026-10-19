//
//  NetworkMetricsSummary.swift
//  DebugLearning
//
//  Created by Ashish Awasthi on 06/10/26.
//

import Foundation

/// Plain value type so Views/ViewModels don't need to depend on URLSessionTaskMetrics directly.
struct NetworkMetricsSummary: Identifiable {
    let id = UUID()
    let host: String
    let dns: TimeInterval?
    let connect: TimeInterval?
    let tls: TimeInterval?
    let timeToFirstByte: TimeInterval?
    let total: TimeInterval
    let protocolName: String?
    let isReusedConnection: Bool

    var description: String {
        func fmt(_ v: TimeInterval?) -> String {
            guard let v else { return "n/a" }
            return String(format: "%.1f ms", v * 1000)
        }
        return """
        host: \(host)
        dns: \(fmt(dns))
        connect: \(fmt(connect))
        tls: \(fmt(tls))
        ttfb: \(fmt(timeToFirstByte))
        total: \(fmt(total))
        protocol: \(protocolName ?? "n/a")  reused: \(isReusedConnection)
        """
    }
}
