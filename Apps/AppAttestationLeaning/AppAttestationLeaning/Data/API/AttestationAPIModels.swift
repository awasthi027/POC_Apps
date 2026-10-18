import Foundation

struct RegisterKeyRequestDTO: Encodable {
    let keyId: String
    let challenge: String
    let clientDataHash: String
    let attestationObject: String
}

struct ProtectedEchoResponseDTO: Decodable {
    let status: String
    let message: String
    let method: String
    let path: String
    let body: String
}

struct ProtectedProfileResponseDTO: Decodable {
    let status: String
    let message: String
    let serverTime: String
}

struct ErrorResponseDTO: Decodable {
    let error: String
}
