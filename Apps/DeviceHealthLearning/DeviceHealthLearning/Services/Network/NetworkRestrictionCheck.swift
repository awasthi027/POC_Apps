//
//  NetworkRestrictionCheck.swift
//  DeviceHealthLearning
//
//  Not part of TelemetrySDK. Diagnoses networks (e.g. corporate / bank branch Wi-Fi) that are
//  "connected" but block or break some traffic:
//  - system proxy / PAC configuration, and what proxy each endpoint actually goes through
//  - TLS with the OS defaults vs TLS capped at 1.2, per endpoint. If the default fails but 1.2 works,
//    a middlebox is mishandling the TLS 1.3 ClientHello (e.g. the larger post-quantum key share)
//  - TLS interception: the certificate chain the device actually receives
//  - QUIC (UDP 443) reachability
//

import Foundation
import Network
import Security

nonisolated enum ProbeOutcome {
    case success(milliseconds: Double, detail: String)
    case failure(String)

    var succeeded: Bool {
        if case .success = self { return true }
        return false
    }
}

nonisolated struct ProxySettings {
    let httpProxy: String?
    let httpsProxy: String?
    let pacURL: String?
    let autoDiscovery: Bool

    var isConfigured: Bool { httpProxy != nil || httpsProxy != nil || pacURL != nil || autoDiscovery }
}

// Per-phase timing for one request, read from URLSessionTaskTransactionMetrics — the same
// DNS/connect/TLS/TTFB/download waterfall a browser's dev tools shows.
//
// The phase recorded in `stalledAt` is the one that was in progress when the request failed or
// timed out, which tells you where to point the finger:
//  - "DNS lookup" / "TCP connect" / "TLS handshake"  -> something on this network path (firewall,
//    proxy, DNS) is interfering. The device never got as far as talking to the app's server.
//  - "waiting for server response"                    -> the connection succeeded and the request
//    was sent, but no response came back in time. This points at the server side (a slow or stuck
//    backend, database query, or downstream dependency) rather than this device's network.
//  - "downloading response"                            -> the server started responding but the
//    transfer stalled.
// This cannot see *why* a server-side stall happened (which query, which downstream call) — that
// needs server-side logs or tracing, which is what `traceId` is for.
nonisolated struct RequestTimingBreakdown {
    let dnsLookupMs: Double?
    let tcpConnectMs: Double?
    let tlsHandshakeMs: Double?
    // Time from the request being sent to the first byte of the response (TTFB).
    let timeToFirstByteMs: Double?
    let contentDownloadMs: Double?
    let stalledAt: String?
    let usedProxy: Bool
    let reusedConnection: Bool

    init(transaction: URLSessionTaskTransactionMetrics) {
        func ms(_ start: Date?, _ end: Date?) -> Double? {
            guard let start, let end else { return nil }
            return end.timeIntervalSince(start) * 1000
        }

        dnsLookupMs = ms(transaction.domainLookupStartDate, transaction.domainLookupEndDate)
        tcpConnectMs = ms(transaction.connectStartDate, transaction.connectEndDate)
        tlsHandshakeMs = ms(transaction.secureConnectionStartDate, transaction.secureConnectionEndDate)
        timeToFirstByteMs = ms(transaction.requestEndDate ?? transaction.connectEndDate, transaction.responseStartDate)
        contentDownloadMs = ms(transaction.responseStartDate, transaction.responseEndDate)
        usedProxy = transaction.isProxyConnection
        reusedConnection = transaction.isReusedConnection

        let isSecure = transaction.request.url?.scheme == "https"
        // Phases in network order; the first one with a start but no end is where things stalled.
        let phases: [(name: String, start: Date?, end: Date?)] = [
            ("DNS lookup", transaction.domainLookupStartDate, transaction.domainLookupEndDate),
            ("TCP connect", transaction.connectStartDate, transaction.connectEndDate),
        ] + (isSecure ? [("TLS handshake", transaction.secureConnectionStartDate, transaction.secureConnectionEndDate)] : [])
            + [
            ("sending request", transaction.requestStartDate, transaction.requestEndDate),
            ("waiting for server response", transaction.requestEndDate, transaction.responseStartDate),
            ("downloading response", transaction.responseStartDate, transaction.responseEndDate),
        ]
        stalledAt = phases.first { $0.start != nil && $0.end == nil }?.name
    }
}

nonisolated struct EndpointReport {
    let url: URL
    // How the system routes this URL: "DIRECT", "HTTPS proxy.example:8080", "PAC …".
    let route: String
    let defaultTLS: ProbeOutcome
    let tls12Only: ProbeOutcome
    // Subject summaries from leaf to root, as received on this network.
    let certificateChain: [String]
    let trustError: String?
    // Phase timing for the default-TLS request (the one representative of real app traffic).
    let timing: RequestTimingBreakdown?
    // Sent as X-Request-Id / W3C traceparent on the default-TLS request, so this exact attempt
    // can be found in server-side logs or an APM trace, if the backend logs those headers.
    let traceId: String
}

nonisolated struct NetworkRestrictionReport {
    let proxy: ProxySettings
    let endpoints: [EndpointReport]
    let quic: ProbeOutcome
    let timestamp: Date
}

nonisolated enum NetworkRestrictionCheck {
    // Add the app endpoints that time out on the restricted network here.
    static let endpoints: [URL] = [
        URL(string: "https://www.apple.com")!,
        URL(string: "https://www.cloudflare.com")!,
    ]
    static let quicHost = "cloudflare.com"
    static let requestTimeout: TimeInterval = 10

    static func run() async -> NetworkRestrictionReport {
        async let quic = probeQUIC(host: quicHost)

        var reports: [EndpointReport] = []
        for url in endpoints {
            reports.append(await probeEndpoint(url))
        }

        return NetworkRestrictionReport(proxy: systemProxy(), endpoints: reports, quic: await quic, timestamp: Date())
    }

    // MARK: - Proxy

    static func systemProxy() -> ProxySettings {
        guard let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any] else {
            return ProxySettings(httpProxy: nil, httpsProxy: nil, pacURL: nil, autoDiscovery: false)
        }

        // Raw keys: the HTTPS constants are macOS-only in the SDK headers, but the dictionary has them on iOS too.
        func proxy(enable: String, host: String, port: String) -> String? {
            guard (settings[enable] as? Int) == 1, let name = settings[host] as? String else { return nil }
            return (settings[port] as? Int).map { "\(name):\($0)" } ?? name
        }

        let pacEnabled = (settings["ProxyAutoConfigEnable"] as? Int) == 1
        return ProxySettings(httpProxy: proxy(enable: "HTTPEnable", host: "HTTPProxy", port: "HTTPPort"),
                             httpsProxy: proxy(enable: "HTTPSEnable", host: "HTTPSProxy", port: "HTTPSPort"),
                             pacURL: pacEnabled ? settings["ProxyAutoConfigURLString"] as? String : nil,
                             autoDiscovery: (settings["ProxyAutoDiscoveryEnable"] as? Int) == 1)
    }

    static func route(for url: URL) -> String {
        guard let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue(),
              let proxies = CFNetworkCopyProxiesForURL(url as CFURL, settings).takeRetainedValue() as? [[CFString: Any]],
              let first = proxies.first,
              let type = first[kCFProxyTypeKey] as? String else {
            return "unknown"
        }

        if type == kCFProxyTypeNone as String {
            return "DIRECT"
        }
        if type == kCFProxyTypeAutoConfigurationURL as String {
            return "PAC \(first[kCFProxyAutoConfigurationURLKey].map { "\($0)" } ?? "")"
        }
        let host = first[kCFProxyHostNameKey] as? String ?? "?"
        let port = (first[kCFProxyPortNumberKey] as? Int).map { ":\($0)" } ?? ""
        let name = type.replacingOccurrences(of: "kCFProxyType", with: "")
        return "\(name) \(host)\(port)"
    }

    // MARK: - TLS

    static func probeEndpoint(_ url: URL) async -> EndpointReport {
        async let defaultProbe = probeTLS(url, capAtTLS12: false)
        async let tls12Probe = probeTLS(url, capAtTLS12: true)
        let (defaultResult, tls12Result) = await (defaultProbe, tls12Probe)

        // Prefer the chain from whichever handshake got far enough to present one.
        let chainSource = defaultResult.chain.isEmpty ? tls12Result : defaultResult
        return EndpointReport(url: url,
                              route: route(for: url),
                              defaultTLS: defaultResult.outcome,
                              tls12Only: tls12Result.outcome,
                              certificateChain: chainSource.chain,
                              trustError: chainSource.trustError,
                              timing: defaultResult.timing,
                              traceId: defaultResult.traceId)
    }

    private static func probeTLS(_ url: URL, capAtTLS12: Bool)
        async -> (outcome: ProbeOutcome, chain: [String], trustError: String?, timing: RequestTimingBreakdown?, traceId: String) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = requestTimeout
        if capAtTLS12 {
            configuration.tlsMaximumSupportedProtocolVersion = .TLSv12
        }

        let delegate = TLSProbeDelegate()
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        // Tag the request so this exact attempt can be matched to a server-side log line or trace,
        // if the backend captures these headers. Most API gateways / load balancers do.
        let traceId = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let spanId = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased().prefix(16))

        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.setValue(traceId, forHTTPHeaderField: "X-Request-Id")
        request.setValue("00-\(traceId)-\(spanId)-01", forHTTPHeaderField: "traceparent")
        let start = DispatchTime.now()

        do {
            let (_, response) = try await session.data(for: request)
            let milliseconds = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
            let status = (response as? HTTPURLResponse).map { "HTTP \($0.statusCode)" } ?? "OK"
            let detail = ([status] + delegate.protocolDetails).joined(separator: " · ")
            return (.success(milliseconds: milliseconds, detail: detail), delegate.chain, delegate.trustError, delegate.timing, traceId)
        } catch let error as URLError {
            return (.failure(describe(error)), delegate.chain, delegate.trustError, delegate.timing, traceId)
        } catch {
            return (.failure(error.localizedDescription), delegate.chain, delegate.trustError, delegate.timing, traceId)
        }
    }

    private static func describe(_ error: URLError) -> String {
        switch error.code {
        case .timedOut: return "Timed out"
        case .secureConnectionFailed: return "TLS handshake failed"
        case .serverCertificateUntrusted, .serverCertificateHasUnknownRoot, .serverCertificateHasBadDate:
            return "Certificate not trusted"
        case .cannotFindHost, .dnsLookupFailed: return "DNS lookup failed"
        case .cannotConnectToHost: return "Connection refused"
        case .networkConnectionLost: return "Connection dropped"
        case .appTransportSecurityRequiresSecureConnection: return "Blocked by ATS"
        default: return "Error \(error.code.rawValue): \(error.localizedDescription)"
        }
    }

    // MARK: - QUIC

    // Time until a QUIC (UDP 443) handshake completes, or why it did not.
    static func probeQUIC(host: String, timeout: TimeInterval = 5) async -> ProbeOutcome {
        let options = NWProtocolQUIC.Options(alpn: ["h3"])
        let connection = NWConnection(host: NWEndpoint.Host(host), port: 443, using: NWParameters(quic: options))
        let queue = DispatchQueue(label: "DeviceHealthLearning.QUICProbe")
        let once = ResumeOnce()

        return await withCheckedContinuation { continuation in
            let start = DispatchTime.now()

            @Sendable func finish(_ outcome: ProbeOutcome) {
                guard once.claim() else { return }
                connection.cancel()
                continuation.resume(returning: outcome)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    let ms = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
                    finish(.success(milliseconds: ms, detail: "QUIC handshake OK"))
                case .failed(let error):
                    finish(.failure("Failed: \(error.localizedDescription)"))
                case .waiting(let error):
                    finish(.failure("Waiting: \(error.localizedDescription)"))
                default:
                    break
                }
            }
            queue.asyncAfter(deadline: .now() + timeout) { finish(.failure("Timed out (UDP 443 likely blocked)")) }
            connection.start(queue: queue)
        }
    }
}

// Records the server certificate chain and negotiated protocol for one request.
private nonisolated final class TLSProbeDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var _chain: [String] = []
    private var _trustError: String?
    private var _protocolDetails: [String] = []
    private var _timing: RequestTimingBreakdown?

    var chain: [String] { lock.withLock { _chain } }
    var trustError: String? { lock.withLock { _trustError } }
    var protocolDetails: [String] { lock.withLock { _protocolDetails } }
    var timing: RequestTimingBreakdown? { lock.withLock { _timing } }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            let certificates = (SecTrustCopyCertificateChain(trust) as? [SecCertificate]) ?? []
            let names = certificates.map { (SecCertificateCopySubjectSummary($0) as String?) ?? "?" }
            var error: CFError?
            let trusted = SecTrustEvaluateWithError(trust, &error)
            lock.withLock {
                _chain = names
                _trustError = trusted ? nil : (error.map { CFErrorCopyDescription($0) as String } ?? "Not trusted")
            }
        }
        // Never bypass validation: the probe should fail exactly like the app would.
        completionHandler(.performDefaultHandling, nil)
    }

    // Called on completion AND on failure/timeout — whatever phase dates got filled in before
    // the failure are still here, which is what lets `RequestTimingBreakdown` find the stall point.
    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        guard let transaction = metrics.transactionMetrics.last else { return }
        var details: [String] = []
        if let version = transaction.negotiatedTLSProtocolVersion {
            details.append(Self.name(of: version))
        }
        if let networkProtocol = transaction.networkProtocolName {
            details.append(networkProtocol)
        }
        if transaction.isProxyConnection {
            details.append("via proxy")
        }
        lock.withLock {
            _protocolDetails = details
            _timing = RequestTimingBreakdown(transaction: transaction)
        }
    }

    private static func name(of version: tls_protocol_version_t) -> String {
        switch version {
        case .TLSv13: return "TLS 1.3"
        case .TLSv12: return "TLS 1.2"
        case .TLSv11: return "TLS 1.1"
        case .TLSv10: return "TLS 1.0"
        default: return "TLS \(version.rawValue)"
        }
    }
}
