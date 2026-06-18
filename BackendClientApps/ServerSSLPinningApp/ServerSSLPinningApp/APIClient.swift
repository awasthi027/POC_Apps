import Foundation

enum APIClientError: Error, Equatable {
    case invalidResponse
    case httpStatus(Int)
    case decoding
    case transport(URLError.Code)
    case pinningFailed(host: String, serverPins: [String], expectedPins: [String])
}

extension APIClientError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Server returned a non-HTTP response."
        case let .httpStatus(code):
            return "HTTP error \(code)."
        case .decoding:
            return "Failed to decode the server response."
        case let .transport(code):
            if code == .cannotConnectToHost || code == .cannotFindHost {
                return "Cannot reach the server. Is it running and reachable?"
            }
            return "Network error (URLError code \(code.rawValue))."
        case let .pinningFailed(host, serverPins, expectedPins):
            return """
            SSL pinning failed for host \(host): the server certificate does not match the pinned value.
            Server presented: \(serverPins.joined(separator: ", "))
            App expected: \(expectedPins.joined(separator: ", "))
            """
        }
    }
}

struct APIClient {
    private let baseURL: URL
    private let session: URLSession
    private let pinningDelegate: SSLPinningSessionDelegate?

    init(baseURL: URL, session: URLSession = .shared, pinningDelegate: SSLPinningSessionDelegate? = nil) {
        self.baseURL = baseURL
        self.session = session
        self.pinningDelegate = pinningDelegate
    }

    func get<T: Decodable>(_ path: String, as type: T.Type = T.self) async throws -> T {
        let requestURL = baseURL.appending(path: path)
        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"

        return try await send(request, as: type)
    }

    func post<Body: Encodable, T: Decodable>(
        _ path: String,
        body: Body,
        as type: T.Type = T.self
    ) async throws -> T {
        let requestURL = baseURL.appending(path: path)
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw APIClientError.decoding
        }

        return try await send(request, as: type)
    }

    private func send<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIClientError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIClientError.httpStatus(httpResponse.statusCode)
            }

            do {
                return try JSONDecoder().decode(type, from: data)
            } catch {
                throw APIClientError.decoding
            }
        } catch let apiError as APIClientError {
            throw apiError
        } catch let urlError as URLError {
            if let failure = pinningDelegate?.lastFailure {
                throw APIClientError.pinningFailed(
                    host: failure.host,
                    serverPins: failure.serverPins,
                    expectedPins: failure.expectedPins
                )
            }
            throw APIClientError.transport(urlError.code)
        } catch {
            throw APIClientError.transport(.unknown)
        }
    }
}

extension APIClient {
    /// Build a client that trusts the system challenge (standard TLS validation, no pinning).
    /// Use this to bootstrap-fetch pins from `/api/pinning/server-pins`.
    static func systemTrusted(
        baseURL: URL,
        configuration: URLSessionConfiguration = .ephemeral
    ) -> APIClient {
        let session = URLSession(configuration: configuration)
        return APIClient(baseURL: baseURL, session: session)
    }

    /// Build a pinned client whose pins are read from the shared `PinStore` (keyed by host).
    static func pinned(
        baseURL: URL,
        pinStore: PinStore,
        configuration: URLSessionConfiguration = .ephemeral
    ) -> APIClient {
        let validator = SSLPinningValidator(pinStore: pinStore)
        let delegate = SSLPinningSessionDelegate(validator: validator)
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        return APIClient(baseURL: baseURL, session: session, pinningDelegate: delegate)
    }
}

