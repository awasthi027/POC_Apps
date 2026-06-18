import Foundation
import Security

struct SecurePingResponse: Codable {
    let message: String
    let secure: Bool
}

struct VerifyResponse: Codable {
    let expectedPin: String
    let pinUsed: String
    let pinningPassed: Bool
    let statusCode: Int?
    let responseBody: String?
    let error: String?
}

enum SSLPinnedAPIError: LocalizedError {
    case invalidBaseURL(String)
    case certificateResourceMissing(String)
    case invalidPEMEncoding
    case invalidHTTPResponse
    case unexpectedStatusCode(Int)
    case unsupportedAuthenticationChallenge
    case missingServerTrust
    case pinnedCertificateMismatch

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL(let value):
            return "The base URL is invalid: \(value)"
        case .certificateResourceMissing(let name):
            return "Could not find the bundled certificate resource '\(name).pem'."
        case .invalidPEMEncoding:
            return "The bundled PEM certificate could not be decoded."
        case .invalidHTTPResponse:
            return "The server response was not an HTTP response."
        case .unexpectedStatusCode(let code):
            return "The server returned an unexpected status code: \(code)."
        case .unsupportedAuthenticationChallenge:
            return "Received an unsupported TLS authentication challenge."
        case .missingServerTrust:
            return "The TLS challenge did not provide a server trust object."
        case .pinnedCertificateMismatch:
            return "The server certificate does not match the bundled pinned certificate."
        }
    }
}

final class SSLPinnedAPIClient {
    private let baseURL: URL
    private let session: URLSession
    private let sessionDelegate: CertificatePinnedSessionDelegate

    init(baseURLString: String, bundle: Bundle = .main) throws {
        guard let baseURL = URL(string: baseURLString) else {
            throw SSLPinnedAPIError.invalidBaseURL(baseURLString)
        }

        self.baseURL = baseURL
        let certificateData = try Self.loadPinnedCertificate(named: "localhost", bundle: bundle)
        let sessionDelegate = CertificatePinnedSessionDelegate(pinnedCertificateData: certificateData)
        self.sessionDelegate = sessionDelegate
        self.session = URLSession(configuration: .ephemeral, delegate: sessionDelegate, delegateQueue: nil)
    }

    func securePing() async throws -> SecurePingResponse {
        let request = try makeRequest(path: "/api/secure/ping", method: "GET")
        return try await send(request, as: SecurePingResponse.self)
    }

    func verify(pin: String? = nil) async throws -> VerifyResponse {
        let queryItems = pin.map { [URLQueryItem(name: "pin", value: $0)] } ?? []
        let request = try makeRequest(path: "/api/client/verify", method: "POST", queryItems: queryItems)
        return try await send(request, as: VerifyResponse.self)
    }

    private func makeRequest(path: String, method: String, queryItems: [URLQueryItem] = []) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw SSLPinnedAPIError.invalidBaseURL(baseURL.absoluteString)
        }

        components.path = path
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw SSLPinnedAPIError.invalidBaseURL(baseURL.absoluteString)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func send<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SSLPinnedAPIError.invalidHTTPResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw SSLPinnedAPIError.unexpectedStatusCode(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func loadPinnedCertificate(named resourceName: String, bundle: Bundle) throws -> Data {
        guard let url = bundle.url(forResource: resourceName, withExtension: "pem") else {
            throw SSLPinnedAPIError.certificateResourceMissing(resourceName)
        }

        let pemString = try String(contentsOf: url, encoding: .utf8)
        let base64Body = pemString
            .components(separatedBy: .newlines)
            .filter { !$0.hasPrefix("-----") && !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .joined()

        guard let certificateData = Data(base64Encoded: base64Body) else {
            throw SSLPinnedAPIError.invalidPEMEncoding
        }

        return certificateData
    }
}

private final class CertificatePinnedSessionDelegate: NSObject, URLSessionDelegate {
    private let pinnedCertificateData: Data

    init(pinnedCertificateData: Data) {
        self.pinnedCertificateData = pinnedCertificateData
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        guard let certificate = SecTrustGetCertificateAtIndex(serverTrust, 0) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let serverCertificateData = SecCertificateCopyData(certificate) as Data
        guard serverCertificateData == pinnedCertificateData else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }
}

extension Encodable {
    func prettyPrintedJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return String(describing: self)
        }

        return string
    }
}

