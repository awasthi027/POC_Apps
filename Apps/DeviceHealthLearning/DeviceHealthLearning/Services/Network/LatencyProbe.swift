//
//  LatencyProbe.swift
//  DeviceHealthLearning
//
//  The SDK measures latency/jitter with SwiftyPing (10 ICMP pings to 1.1.1.1).
//  To keep this sample dependency-free, each probe here times a TCP handshake to 1.1.1.1:443
//  instead. The maths is the same: one-way latency = avg RTT / 2, one-way jitter = stddev RTT / 2.
//

import Foundation
import Network

nonisolated struct NetworkStatResult {
    // One-way values in milliseconds. nil when fewer than 2 probes succeeded.
    let latency: Float?
    let jitter: Float?
    // Share of probes that failed or timed out, 0...1.
    let packetLoss: Float
    let timestamp: Date

    var isFresh: Bool { -timestamp.timeIntervalSinceNow < 5 * 60 }
}

nonisolated enum LatencyProbe {
    static let targetHost = "1.1.1.1"
    static let targetPort: NWEndpoint.Port = 443
    static let numberOfProbesInSet = 10

    // Always returns a result so a failed measurement is visible as packet loss instead of "no data".
    static func measure(count: Int = numberOfProbesInSet) async -> NetworkStatResult {
        var roundTrips: [Double] = []
        for _ in 0..<count {
            if let rtt = await roundTripMilliseconds() {
                roundTrips.append(rtt)
            }
        }

        let packetLoss = Float(count - roundTrips.count) / Float(count)

        // SDK requires a full set of results; accept anything with at least 2 so stddev is meaningful.
        guard roundTrips.count >= 2 else {
            return NetworkStatResult(latency: nil, jitter: nil, packetLoss: packetLoss, timestamp: Date())
        }

        let average = roundTrips.reduce(0, +) / Double(roundTrips.count)
        let variance = roundTrips.reduce(0) { $0 + pow($1 - average, 2) } / Double(roundTrips.count)
        return NetworkStatResult(latency: Float(average / 2),
                                 jitter: Float(variance.squareRoot() / 2),
                                 packetLoss: packetLoss,
                                 timestamp: Date())
    }

    // Time from `start` to `.ready` for one TCP connection, or nil on failure / timeout.
    private static func roundTripMilliseconds(timeout: TimeInterval = 3) async -> Double? {
        let connection = NWConnection(host: NWEndpoint.Host(targetHost), port: targetPort, using: .tcp)
        let queue = DispatchQueue(label: "DeviceHealthLearning.LatencyProbe")
        let once = ResumeOnce()

        return await withCheckedContinuation { continuation in
            let start = DispatchTime.now()

            @Sendable func finish(_ value: Double?) {
                guard once.claim() else { return }
                connection.cancel()
                continuation.resume(returning: value)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    finish(Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000)
                case .failed, .cancelled:
                    finish(nil)
                default:
                    break
                }
            }
            queue.asyncAfter(deadline: .now() + timeout) { finish(nil) }
            connection.start(queue: queue)
        }
    }
}

// Guards a continuation against being resumed twice.
nonisolated final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if done { return false }
        done = true
        return true
    }
}
