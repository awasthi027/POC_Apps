import CryptoKit
import DeviceCheck
import Foundation

actor DeviceCheckAttestationProvider: AttestationProvider {
    private let appAttestService = DCAppAttestService.shared
    private let keyIdStore = UserDefaults.standard
    private let keyIdStoreKey = "app_attest_key_id"
    private var keyId: String?
    private let bundleIdentifier = Bundle.main.bundleIdentifier ?? "unknown.bundle.id"

    func createRegistrationCommand() async throws -> RegisterKeyCommand {
        let activeKeyId = try await getOrCreateKeyId()
        let timestamp = String(Int64(Date().timeIntervalSince1970 * 1_000))
        let nonce = UUID().uuidString
        let challenge = [
            "REGISTER",
            bundleIdentifier,
            timestamp,
            nonce,
            activeKeyId
        ].joined(separator: "\n")
        let challengeData = Data(challenge.utf8)
        let clientDataHash = SHA256.hash(data: challengeData)
        let attestationObject = try await attestKey(
            keyId: activeKeyId,
            clientDataHash: Data(clientDataHash)
        )

        return await RegisterKeyCommand(
            keyId: activeKeyId,
            challengeBase64Url: challengeData.base64URLEncodedString(),
            clientDataHashBase64Url: Data(clientDataHash).base64URLEncodedString(),
            attestationObjectBase64Url: attestationObject.base64URLEncodedString()
        )
    }

    func createAssertion(for binding: RequestBinding) async throws -> AttestationAssertion {
        let activeKeyId = try await getOrCreateKeyId()
        let timestamp = String(Int64(Date().timeIntervalSince1970 * 1_000))
        let nonce = UUID().uuidString
        let bodyHash = SHA256.hash(data: binding.bodyData)
        let bodyHashB64Url = await Data(bodyHash).base64URLEncodedString()
        let canonical = [
            binding.method.uppercased(),
            binding.path,
            bodyHashB64Url,
            timestamp,
            nonce,
            activeKeyId
        ].joined(separator: "\n")
        let clientDataHash = SHA256.hash(data: Data(canonical.utf8))
        let assertionObject = try await generateAssertion(
            keyId: activeKeyId,
            clientDataHash: Data(clientDataHash)
        )

        return await AttestationAssertion(
            keyId: activeKeyId,
            assertionObjectBase64Url: assertionObject.base64URLEncodedString(),
            clientDataHashBase64Url: Data(clientDataHash).base64URLEncodedString(),
            timestampEpochMs: timestamp,
            nonce: nonce
        )
    }

    private func getOrCreateKeyId() async throws -> String {
        guard appAttestService.isSupported else {
            throw AppError.appAttestUnavailable
        }

        if let keyId {
            return keyId
        }

        if let stored = keyIdStore.string(forKey: keyIdStoreKey), !stored.isEmpty {
            keyId = stored
            return stored
        }

        let generatedKeyId = try await generateKey()
        keyIdStore.set(generatedKeyId, forKey: keyIdStoreKey)
        keyId = generatedKeyId
        return generatedKeyId
    }

    private func generateKey() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            appAttestService.generateKey { keyId, error in
                if let keyId {
                    continuation.resume(returning: keyId)
                } else {
                    continuation.resume(throwing: error ?? AppError.keyUnavailable)
                }
            }
        }
    }

    private func attestKey(keyId: String, clientDataHash: Data) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            appAttestService.attestKey(keyId, clientDataHash: clientDataHash) { attestationObject, error in
                if let attestationObject {
                    continuation.resume(returning: attestationObject)
                } else {
                    continuation.resume(throwing: error ?? AppError.cryptographicFailure)
                }
            }
        }
    }

    private func generateAssertion(keyId: String, clientDataHash: Data) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            appAttestService.generateAssertion(keyId, clientDataHash: clientDataHash) { assertionObject, error in
                if let assertionObject {
                    continuation.resume(returning: assertionObject)
                } else {
                    continuation.resume(throwing: error ?? AppError.cryptographicFailure)
                }
            }
        }
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
