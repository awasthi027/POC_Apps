import Foundation

struct RegisterKeyCommand {
    let keyId: String
    let challengeBase64Url: String
    let clientDataHashBase64Url: String
    let attestationObjectBase64Url: String
}

struct AttestationAssertion {
    let keyId: String
    let assertionObjectBase64Url: String
    let clientDataHashBase64Url: String
    let timestampEpochMs: String
    let nonce: String
}

struct ProtectedEchoCommand {
    let payload: String
    let assertion: AttestationAssertion
}

struct ProtectedEchoResult {
    let status: String
    let message: String
    let method: String
    let path: String
    let body: String
}

struct ProtectedProfileResult {
    let status: String
    let message: String
    let serverTime: String
}

struct RequestBinding {
    let method: String
    let path: String
    let bodyData: Data
}
