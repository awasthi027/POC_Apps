import Foundation

protocol AttestationAPIClient {
    func register(baseURL: String, request: RegisterKeyRequestDTO) async throws
    func protectedEcho(
        baseURL: String,
        payloadData: Data,
        assertion: AttestationAssertion
    ) async throws -> ProtectedEchoResponseDTO
    func protectedProfile(
        baseURL: String,
        assertion: AttestationAssertion
    ) async throws -> ProtectedProfileResponseDTO
}

struct URLSessionAttestationAPIClient: AttestationAPIClient {
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    func register(baseURL: String, request: RegisterKeyRequestDTO) async throws {
        let endpoint = try makeURL(baseURL: baseURL, path: "/attestation/register")
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await session.data(for: urlRequest)
        try throwIfNotSuccess(response: response, responseData: data)
    }

    func protectedEcho(
        baseURL: String,
        payloadData: Data,
        assertion: AttestationAssertion
    ) async throws -> ProtectedEchoResponseDTO {
        let endpoint = try makeURL(baseURL: baseURL, path: "/protected/echo")
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(assertion.keyId, forHTTPHeaderField: "X-AppAttest-Key-Id")
        urlRequest.setValue(assertion.assertionObjectBase64Url, forHTTPHeaderField: "X-AppAttest-Assertion")
        urlRequest.setValue(assertion.clientDataHashBase64Url, forHTTPHeaderField: "X-AppAttest-Client-Data-Hash")
        urlRequest.setValue(assertion.timestampEpochMs, forHTTPHeaderField: "X-AppAttest-Timestamp")
        urlRequest.setValue(assertion.nonce, forHTTPHeaderField: "X-AppAttest-Nonce")
        urlRequest.httpBody = payloadData

        let (data, response) = try await session.data(for: urlRequest)
        try throwIfNotSuccess(response: response, responseData: data)
        return try decoder.decode(ProtectedEchoResponseDTO.self, from: data)
    }

    func protectedProfile(
        baseURL: String,
        assertion: AttestationAssertion
    ) async throws -> ProtectedProfileResponseDTO {
        let endpoint = try makeURL(baseURL: baseURL, path: "/protected/profile")
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue(assertion.keyId, forHTTPHeaderField: "X-AppAttest-Key-Id")
        urlRequest.setValue(assertion.assertionObjectBase64Url, forHTTPHeaderField: "X-AppAttest-Assertion")
        urlRequest.setValue(assertion.clientDataHashBase64Url, forHTTPHeaderField: "X-AppAttest-Client-Data-Hash")
        urlRequest.setValue(assertion.timestampEpochMs, forHTTPHeaderField: "X-AppAttest-Timestamp")
        urlRequest.setValue(assertion.nonce, forHTTPHeaderField: "X-AppAttest-Nonce")

        let (data, response) = try await session.data(for: urlRequest)
        try throwIfNotSuccess(response: response, responseData: data)
        return try decoder.decode(ProtectedProfileResponseDTO.self, from: data)
    }

    private func makeURL(baseURL: String, path: String) throws -> URL {
        guard let base = URL(string: baseURL) else {
            throw AppError.invalidURL
        }
        guard let url = URL(string: path, relativeTo: base)?.absoluteURL else {
            throw AppError.invalidURL
        }
        return url
    }

    private func throwIfNotSuccess(response: URLResponse, responseData: Data?) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.serverError(-1, "Invalid HTTP response.")
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorText: String
            if let responseData, let parsedError = try? decoder.decode(ErrorResponseDTO.self, from: responseData) {
                errorText = parsedError.error
            } else if let responseData, let body = String(data: responseData, encoding: .utf8), !body.isEmpty {
                errorText = body
            } else {
                errorText = "Unknown error"
            }

            if httpResponse.statusCode == 400 {
                throw AppError.badRequest(errorText)
            }
            if httpResponse.statusCode == 401 {
                throw AppError.unauthorized(errorText)
            }
            throw AppError.serverError(httpResponse.statusCode, errorText)
        }
    }
}
