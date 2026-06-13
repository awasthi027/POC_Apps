import Foundation

struct SignedRequestContext {
    let sessionId: String
    let hmacKey: Data
}

final class SignedRequestExecutor {
    private let environment: SecureNetworkEnvironment
    private let signer: ProtectedRequestSigner

    init(
        environment: SecureNetworkEnvironment,
        signer: ProtectedRequestSigner
    ) {
        self.environment = environment
        self.signer = signer
    }

    func execute(
        auth: SignedRequestContext,
        method: String,
        path: String,
        bodyData: Data?,
        completion: @escaping (Result<(data: Data, response: HTTPURLResponse), Error>) -> Void
    ) {
        guard let url = URL(string: "\(environment.baseURL)\(path)") else {
            completion(.failure(NSError(domain: "SignedRequestExecutor", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid API URL"])))
            return
        }

        let timestampMillis = String(Int(Date().timeIntervalSince1970 * 1000))
        let nonce = UUID().uuidString

        guard let signature = signer.sign(
            hmacKey: auth.hmacKey,
            sessionId: auth.sessionId,
            certDeviceId: environment.deviceId,
            method: method,
            path: path,
            timestampMillis: timestampMillis,
            nonce: nonce
        ) else {
            completion(.failure(NSError(domain: "SignedRequestExecutor", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create request signature"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = bodyData
        if bodyData != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        request.setValue(auth.sessionId, forHTTPHeaderField: "X-Session-Id")
        request.setValue(timestampMillis, forHTTPHeaderField: "X-Request-Timestamp")
        request.setValue(nonce, forHTTPHeaderField: "X-Request-Nonce")
        request.setValue(signature, forHTTPHeaderField: "X-Request-Signature")

        environment.session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "SignedRequestExecutor", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])))
                return
            }

            let responseData = data ?? Data()
            if (200..<300).contains(httpResponse.statusCode) {
                completion(.success((responseData, httpResponse)))
                return
            }

            let body = String(data: responseData, encoding: .utf8) ?? ""
            completion(.failure(NSError(domain: "SignedRequestExecutor", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode) \(body)"])))
        }.resume()
    }
}

