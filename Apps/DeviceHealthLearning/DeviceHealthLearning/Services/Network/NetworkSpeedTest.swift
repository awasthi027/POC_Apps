//
//  NetworkSpeedTest.swift
//  DeviceHealthLearning
//
//  Same idea as TelemetrySDK NetworkSpeedSampler (time a download and an upload, convert to Mbps),
//  which the SDK has but does not ship yet (INTELSDK-658). The SDK targets httpbin.org; this sample uses
//  Cloudflare's public speed-test endpoints instead, and caps each transfer by time so a bad network
//  still produces a result quickly.
//

import Foundation

nonisolated struct NetworkSpeedResult {
    // Megabits per second. nil when nothing was transferred.
    let downloadMbps: Float?
    let uploadMbps: Float?
    let timestamp: Date
}

nonisolated enum NetworkSpeedTest {
    static let downloadURL = URL(string: "https://speed.cloudflare.com/__down?bytes=25000000")!
    static let uploadURL = URL(string: "https://speed.cloudflare.com/__up")!
    static let uploadSizeInBytes = 5_000_000
    // Each transfer stops after this long; speed is computed from what got through.
    static let maxTransferDuration: TimeInterval = 8

    static func measure() async -> NetworkSpeedResult {
        let download = await TransferMeter.run(request: URLRequest(url: downloadURL), uploadBody: nil,
                                               maxDuration: maxTransferDuration)

        var uploadRequest = URLRequest(url: uploadURL)
        uploadRequest.httpMethod = "POST"
        let upload = await TransferMeter.run(request: uploadRequest, uploadBody: Data(count: uploadSizeInBytes),
                                             maxDuration: maxTransferDuration)

        return NetworkSpeedResult(downloadMbps: download, uploadMbps: upload, timestamp: Date())
    }
}

// Counts bytes moved by one URLSession task and turns them into Mbps.
private nonisolated final class TransferMeter: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private let isUpload: Bool
    private var bytes: Int64 = 0
    private var start = DispatchTime.now()
    private var continuation: CheckedContinuation<Float?, Never>?

    private init(isUpload: Bool) {
        self.isUpload = isUpload
    }

    static func run(request: URLRequest, uploadBody: Data?, maxDuration: TimeInterval) async -> Float? {
        let meter = TransferMeter(isUpload: uploadBody != nil)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.timeoutIntervalForRequest = maxDuration + 5
        let session = URLSession(configuration: configuration, delegate: meter, delegateQueue: nil)
        defer { session.invalidateAndCancel() }

        return await withCheckedContinuation { continuation in
            meter.lock.withLock {
                meter.continuation = continuation
                meter.start = .now()
            }

            let task = uploadBody.map { session.uploadTask(with: request, from: $0) } ?? session.dataTask(with: request)
            task.resume()

            DispatchQueue.global().asyncAfter(deadline: .now() + maxDuration) {
                meter.finish()
                task.cancel()
            }
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard !isUpload else { return }
        lock.withLock { bytes += Int64(data.count) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard isUpload else { return }
        lock.withLock { bytes = totalBytesSent }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        finish()
    }

    // Resumes once, on completion or at the deadline, whichever comes first.
    func finish() {
        let (continuation, mbps): (CheckedContinuation<Float?, Never>?, Float?) = lock.withLock {
            let continuation = self.continuation
            self.continuation = nil
            let seconds = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000
            let mbps = bytes > 0 && seconds > 0 ? Float(Double(bytes) * 8 / seconds / 1_000_000) : nil
            return (continuation, mbps)
        }
        continuation?.resume(returning: mbps)
    }
}
