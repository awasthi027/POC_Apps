import Foundation

enum AppError: LocalizedError {
    case invalidURL
    case badRequest(String)
    case unauthorized(String)
    case serverError(Int, String)
    case invalidPayload
    case keyUnavailable
    case cryptographicFailure
    case appAttestUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid backend URL."
        case .badRequest(let message):
            return message
        case .unauthorized(let message):
            return message
        case .serverError(let code, let body):
            return "Server error \(code): \(body)"
        case .invalidPayload:
            return "Payload must be a valid JSON object string."
        case .keyUnavailable:
            return "Attestation key is unavailable."
        case .cryptographicFailure:
            return "Unable to create attestation signature."
        case .appAttestUnavailable:
            return "App Attest is unavailable on this device."
        }
    }
}
