import Foundation

enum NetworkFailure: Sendable, Equatable {
    case offline      // no route / connection lost: not the event's fault, not counted
    case timeout
    case cancelled
    case other
}

/// Every possible outcome of one upload attempt, classified. The coordinator switches over this exhaustively.
enum UploadResult: Sendable, Equatable {
    /// HTTP 200 with a valid, matching acknowledgment body. The ONLY result that may delete events.
    case acknowledged(UploadAcknowledgment)
    /// 2xx without a valid acknowledgment (202/204, bad JSON, wrong batch_id). Nothing may be deleted.
    case malformedAcknowledgment
    case rateLimited(retryAfter: TimeInterval?)
    case serverError(status: Int, retryAfter: TimeInterval?)
    /// 401 that persisted after one credential refresh.
    case authenticationFailed
    /// 403 and other unexpected 3xx/4xx: configuration problem, not transient.
    case configurationError(status: Int)
    case payloadTooLarge
    /// 400/422: the server could not accept this batch as sent.
    case payloadRejected(status: Int)
    case network(NetworkFailure)
}

/// Seam for the network. The default is `URLSessionTransport`; tests inject a fake.
protocol AnalyticsTransport: Sendable {
    func send(_ request: UploadRequest) async -> UploadResult
}

/// Foreground `URLSession` upload. No synchronous waiting anywhere; cancellation-aware.
///
/// Background `URLSession` is intentionally not used: batches are small (≤ 256 KiB), the queue is already
/// durable, and the process is relaunched by the OS rarely enough that delegate re-attachment, file-based
/// bodies and lost-response handling would add much complexity for little gain. Revisit for large payloads.
struct URLSessionTransport: AnalyticsTransport {
    let endpoint: URL
    let credentials: any CredentialProvider
    let session: URLSession
    let timeout: TimeInterval
    let clock: any AnalyticsClock
    let networkPolicy: @Sendable () -> NetworkPolicy

    static func makeSession(timeout: TimeInterval) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout * 2
        configuration.waitsForConnectivity = false   // the coordinator owns "wait until online"
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }

    func send(_ request: UploadRequest) async -> UploadResult {
        let body: Data
        do { body = try request.encodedBody() } catch { return .payloadRejected(status: 0) }

        var token = await credentials.currentToken()
        var result = await perform(request, body: body, token: token)
        // One refresh-and-retry on 401, then give up (the coordinator pauses; it never loops on 401).
        if case .authenticationFailed = result, let refreshed = await credentials.refreshToken(), refreshed != token {
            token = refreshed
            result = await perform(request, body: body, token: token)
        }
        return result
    }

    private func perform(_ request: UploadRequest, body: Data, token: String?) async -> UploadResult {
        var urlRequest = URLRequest(url: endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue(request.batchID, forHTTPHeaderField: "Idempotency-Key")
        urlRequest.setValue("AnalyticsSDK/\(request.sdkVersion)", forHTTPHeaderField: "User-Agent")
        if let token { urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if networkPolicy() == .unmeteredOnly {
            urlRequest.allowsCellularAccess = false
            urlRequest.allowsExpensiveNetworkAccess = false
            urlRequest.allowsConstrainedNetworkAccess = false
        }

        do {
            let (data, response) = try await session.upload(for: urlRequest, from: body)
            guard let http = response as? HTTPURLResponse else { return .network(.other) }
            let retryAfter = RetryAfter.parse(http.value(forHTTPHeaderField: "Retry-After"), now: clock.now())
            return Self.classify(status: http.statusCode, data: data, retryAfter: retryAfter, request: request)
        } catch {
            return Self.classify(error: error)
        }
    }

    static func classify(status: Int, data: Data, retryAfter: TimeInterval?, request: UploadRequest) -> UploadResult {
        switch status {
        case 200:
            guard let ack = try? JSONDecoder().decode(UploadAcknowledgment.self, from: data), ack.batchID == request.batchID else {
                return .malformedAcknowledgment
            }
            return .acknowledged(ack)
        case 201...299:
            // 202 Accepted means "queued, not durable"; 204 carries no acknowledgment. Neither may delete anything.
            return .malformedAcknowledgment
        case 401: return .authenticationFailed
        case 408: return .serverError(status: status, retryAfter: retryAfter)
        case 413: return .payloadTooLarge
        case 400, 422: return .payloadRejected(status: status)
        case 429: return .rateLimited(retryAfter: retryAfter)
        case 500...599: return .serverError(status: status, retryAfter: retryAfter)
        default: return .configurationError(status: status)
        }
    }

    static func classify(error: Error) -> UploadResult {
        if error is CancellationError { return .network(.cancelled) }
        guard let urlError = error as? URLError else { return .network(.other) }
        switch urlError.code {
        case .cancelled: return .network(.cancelled)
        case .timedOut: return .network(.timeout)
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff,
             .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return .network(.offline)
        default: return .network(.other)
        }
    }
}
