import Foundation

enum PinnedAPIDemoError: LocalizedError {
    case invalidBaseURL
    case certificateNotFound(String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "Invalid base URL. Update the server URL before running."
        case let .certificateNotFound(name):
            return "Certificate \(name).cer not found in app bundle."
        }
    }
}

// GET /api/pinning/server-pin
struct ServerPinResponse: Decodable {
    let pin: String
    let sha256Hex: String
    let note: String
}

// GET /api/pinning/server-pins
struct ServerPinsResponse: Decodable {
    let certificatePin: String
    let certificateSha256Hex: String
    let publicKeyPin: String
    let publicKeySha256Hex: String
    let algorithm: String
    let format: String
    let note: String
}

// POST /api/pinning/validate request body
struct PinValidationRequest: Encodable {
    let pin: String
}

// POST /api/pinning/validate response
struct PinValidationResponse: Decodable {
    let matched: Bool
    let providedPin: String
    let expectedPin: String
    let message: String
}

/// Result of validating `/server-pin` against the pins fetched from `/server-pins`.
struct ServerPinTrustResult {
    let pin: String
    let matched: Bool
    let expectedPins: [String]
}

/// Talks to the local Spring Boot `server-ssl-pinning` service.
/// Endpoints:
/// - GET  /api/pinning/server-pin
/// - GET  /api/pinning/server-pins
/// - POST /api/pinning/validate  body: { "pin": "sha256/..." }
struct PinnedAPIDemoService {
    let baseURLString: String
    let certificateResourceName: String
    let pinStore: PinStore

    init(
        baseURLString: String = "https://localhost:8443",
        certificateResourceName: String = "local-host",
        pinStore: PinStore = .shared
    ) {
        self.baseURLString = baseURLString
        self.certificateResourceName = certificateResourceName
        self.pinStore = pinStore
    }

    private func resolvedURLAndHost() throws -> (URL, String) {
        guard let baseURL = URL(string: baseURLString), let host = baseURL.host() else {
            throw PinnedAPIDemoError.invalidBaseURL
        }
        return (baseURL, host)
    }

    /// Step 1 — Fetch pins from `/api/pinning/server-pins` by TRUSTING THE SYSTEM
    /// CHALLENGE (standard TLS validation, no pinning), then store them per host.
    @discardableResult
    func provisionServerPins() async throws -> ServerPinsResponse {
        let (baseURL, host) = try resolvedURLAndHost()
        let client = APIClient.systemTrusted(baseURL: baseURL)
        let response = try await client.get("api/pinning/server-pins", as: ServerPinsResponse.self)

        // Store both pins against the host.
        pinStore.setPins([response.certificatePin, response.publicKeyPin], forHost: host)
        return response
    }

    /// Step 2 — Call `/api/pinning/server-pin` and validate its advertised pin
    /// against the pins previously fetched from `/api/pinning/server-pins`.
    func fetchServerPinAndValidateTrust() async throws -> ServerPinTrustResult {
        let (baseURL, host) = try resolvedURLAndHost()
        let client = APIClient.systemTrusted(baseURL: baseURL)
        let response = try await client.get("api/pinning/server-pin", as: ServerPinResponse.self)

        let stored = pinStore.pins(forHost: host)
        let matched = stored.contains(response.pin)
        return ServerPinTrustResult(
            pin: response.pin,
            matched: matched,
            expectedPins: Array(stored).sorted()
        )
    }

    /// Calls POST /api/pinning/validate with the given pin.
    func validate(pin: String) async throws -> PinValidationResponse {
        let (baseURL, _) = try resolvedURLAndHost()
        let client = APIClient.systemTrusted(baseURL: baseURL)
        return try await client.post(
            "api/pinning/validate",
            body: PinValidationRequest(pin: pin),
            as: PinValidationResponse.self
        )
    }
}

