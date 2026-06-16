//
//  EcdhClient.swift
//  SecurityTestApp
//
//  Created by Ashish Awasthi on 13/06/26.
//

import Foundation
import CryptoKit
import Security

class EcdhClient {
    private static let x25519SpkiPrefix = Data([0x30, 0x2a, 0x30, 0x05, 0x06, 0x03, 0x2b, 0x65, 0x6e, 0x03, 0x21, 0x00])

    private let deviceId: String
    private let deviceType: String

    private var clientPrivateKey: Curve25519.KeyAgreement.PrivateKey?
    private var clientPublicKeyBytes: Data?
    private var clientInitPublicKeyBytes: Data?
    private var clientInitPublicKeyBase64: String?
    private var clientNonceBytes: Data?
    private var clientNonceBase64: String?

    private var sessionId: String?
    private var serverPublicKeyBytes: Data?
    private var serverPublicKeyBase64: String?
    private var serverNonceBytes: Data?
    private var serverNonceBase64: String?
    private var hmacKey: Data?
    private var transcriptLineSeparator: String = "\n"
    private var selectedTranscript: String?
    private var clientFinishLabel: String = "client-finish"
    private var serverFinishLabel: String = "server-finish"

    private let session: URLSession
    private let baseURL: String

    init(
        session: URLSession,
        baseURL: String,
        deviceId: String,
        deviceType: String = "mobile"
    ) {
        self.session = session
        self.baseURL = baseURL
        self.deviceId = deviceId
        self.deviceType = deviceType
    }

    // Step 1: Generate client X25519 keypair and nonce
    func generateClientKeys() {
        clientPrivateKey = Curve25519.KeyAgreement.PrivateKey()
        clientPublicKeyBytes = clientPrivateKey!.publicKey.rawRepresentation
        clientNonceBytes = Data((0..<32).map { _ in UInt8.random(in: 0...255) })

        print("✓ Generated client X25519 keypair")
        print("  Client public key (base64): \(clientPublicKeyBytes!.base64EncodedString())")

        print("  Client nonce (base64): \(clientNonceBytes!.base64EncodedString())")
    }

    // Step 2: Call /ecdh/init
    func callInit(completion: @escaping (EcdhInitResponse?, Error?) -> Void) {
        guard let publicKey = clientPublicKeyBytes, let nonce = clientNonceBytes else {
            completion(nil, NSError(domain: "EcdhClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Keys not generated"]))
            return
        }

        let initPublicKey = encodeClientPublicKeyForInit(publicKey)
        self.clientInitPublicKeyBytes = initPublicKey
        self.clientInitPublicKeyBase64 = initPublicKey.base64EncodedString()
        self.clientNonceBase64 = nonce.base64EncodedString()

        let request = EcdhInitRequest(
            deviceId: deviceId,
            deviceType: deviceType,
            clientPublicKey: self.clientInitPublicKeyBase64!,
            clientNonce: self.clientNonceBase64!
        )

        guard let url = URL(string: "\(baseURL)/ecdh/init") else {
            completion(nil, NSError(domain: "EcdhClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try? JSONEncoder().encode(request)

        let task = session.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                completion(nil, error)
                return
            }

            guard let data = data else {
                completion(nil, NSError(domain: "EcdhClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data"]))
                return
            }

            Task { @MainActor in
                do {
                    print("Data: Error \(String(data: data, encoding: .utf8) ?? "")")
                    let response = try JSONDecoder().decode(EcdhInitResponse.self, from: data)
                    print("✓ /ecdh/init succeeded")
                    print("  Session ID: \(response.sessionId)")
                    print("  Server proof: \(response.serverProof)")

                    // Extract server values
                    self.sessionId = response.sessionId
                    self.serverPublicKeyBytes = Data(base64Encoded: response.serverPublicKey)
                    self.serverPublicKeyBase64 = response.serverPublicKey
                    self.serverNonceBytes = Data(base64Encoded: response.serverNonce)
                    self.serverNonceBase64 = response.serverNonce

                    // Compute shared secret and negotiate proof parameters against server proof.
                    self.deriveHmacKey(serverProofBase64: response.serverProof)

                    completion(response, nil)
                } catch {
                    completion(nil, error)
                }
            }
        }
        task.resume()
    }

    private func deriveHmacKey(serverProofBase64: String) {
        guard let serverPubKeyBytes = serverPublicKeyBytes,
              let clientPriv = clientPrivateKey,
              let clientNonce = clientNonceBytes,
              let serverNonce = serverNonceBytes,
              let sessionId = sessionId else {
            print("✗ Missing required data for key derivation")
            return
        }

        do {
            let serverPubKey = try parseServerPublicKey(serverPubKeyBytes)
            let sharedSecret = try clientPriv.sharedSecretFromKeyAgreement(with: serverPubKey)

            print("✓ Computed ECDH shared secret")

            // Mirror the server's CryptoService.deriveSessionKeys exactly:
            //   salt = clientNonce || serverNonce
            //   prk  = HMAC-SHA256(salt, sharedSecret)            (HKDF-Extract)
            //   hmacKey = HKDF-Expand(prk, "secure-channel-v1|<sessionId>|hmac", 32)
            // CryptoKit's hkdfDerivedSymmetricKey performs HKDF (Extract+Expand)
            // with the shared secret as IKM, so it produces the same 32-byte key.
            let salt = clientNonce + serverNonce
            let info = "secure-channel-v1|\(sessionId)|hmac".data(using: .utf8)!

            let hkdfKey = sharedSecret.hkdfDerivedSymmetricKey(
                using: SHA256.self,
                salt: salt,
                sharedInfo: info,
                outputByteCount: 32
            )
            let keyData = hkdfKey.withUnsafeBytes { Data($0) }

            self.hmacKey = keyData
            self.transcriptLineSeparator = "\n"
            self.serverFinishLabel = "server-finish"
            self.clientFinishLabel = "client-finish"
            self.selectedTranscript = buildTranscript()

            // Sanity check: the server proof is HMAC(hmacKey, transcript).
            // If this matches, the derived key and transcript are correct.
            if let transcript = self.selectedTranscript,
               let transcriptData = transcript.data(using: .utf8) {
                let serverSig = HMAC<SHA256>.authenticationCode(
                    for: transcriptData,
                    using: SymmetricKey(data: keyData)
                )
                let computedServerProof = Data(serverSig).base64EncodedString()
                if computedServerProof == serverProofBase64 {
                    print("✓ Derived HMAC key and verified server proof")
                } else {
                    print("✗ Server proof mismatch — derivation/transcript may be off")
                    print("  expected: \(serverProofBase64)")
                    print("  computed: \(computedServerProof)")
                }
            }
        } catch {
            print("✗ Failed to derive HMAC key: \(error)")
        }
    }


    // Java servers often exchange X25519 keys as X.509 SPKI-encoded bytes.
    private func encodeClientPublicKeyForInit(_ rawPublicKey: Data) -> Data {
        guard rawPublicKey.count == 32 else { return rawPublicKey }
        return EcdhClient.x25519SpkiPrefix + rawPublicKey
    }

    private func parseServerPublicKey(_ keyBytes: Data) throws -> Curve25519.KeyAgreement.PublicKey {
        if keyBytes.count == 32 {
            return try Curve25519.KeyAgreement.PublicKey(rawRepresentation: keyBytes)
        }

        if keyBytes.count == 44, keyBytes.starts(with: EcdhClient.x25519SpkiPrefix) {
            let raw = keyBytes.dropFirst(EcdhClient.x25519SpkiPrefix.count)
            return try Curve25519.KeyAgreement.PublicKey(rawRepresentation: Data(raw))
        }

        throw NSError(
            domain: "EcdhClient",
            code: -2,
            userInfo: [NSLocalizedDescriptionKey: "Unsupported server public key format (\(keyBytes.count) bytes)"]
        )
    }

    // Step 4: Compute client proof for /ecdh/confirm
    func computeClientProof() -> String? {
        guard let hmacKey = hmacKey else {
            print("✗ HMAC key not derived")
            return nil
        }

        // Transcript format (matching Java implementation):
        // "client-init|<clientPubKey>|<clientNonce>\nserver-init|<serverPubKey>|<serverNonce>"
        let transcript = buildTranscript()
        let finishMsg = transcript + transcriptLineSeparator + clientFinishLabel

        guard let finishData = finishMsg.data(using: .utf8) else {
            return nil
        }

        let signature = HMAC<SHA256>.authenticationCode(
            for: finishData,
            using: SymmetricKey(data: hmacKey)
        )

        let proofData = Data(signature)
        let proofBase64 = proofData.base64EncodedString()

        print("✓ Computed client proof")
        print("  Client proof (base64): \(proofBase64)")

        return proofBase64
    }

    // Build transcript for proof validation
    private func buildTranscript() -> String {
        if let selectedTranscript = selectedTranscript {
            return selectedTranscript
        }

        // Must match the server's EcdhHandshakeService.transcript():
        //   String.join("\n", sessionId, clientPublicKey, serverPublicKey, clientNonce, serverNonce)
        // where clientPublicKey is the exact base64 SPKI string the client sent in /ecdh/init,
        // serverPublicKey/serverNonce are the base64 strings returned by the server, and
        // clientNonce is the base64 string the client sent.
        guard let sessionId = sessionId,
              let clientPub = clientInitPublicKeyBase64,
              let serverPub = serverPublicKeyBase64,
              let clientNonce = clientNonceBase64,
              let serverNonce = serverNonceBase64 else {
            return ""
        }

        return [sessionId, clientPub, serverPub, clientNonce, serverNonce].joined(separator: "\n")
    }
    // Step 5: Call /ecdh/confirm with client proof
    func callConfirm(clientProof: String, completion: @escaping (EcdhConfirmResponse?, Error?) -> Void) {
        guard let sessionId = sessionId else {
            completion(nil, NSError(domain: "EcdhClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "No session ID"]))
            return
        }

        let request = EcdhConfirmRequest(
            sessionId: sessionId,
            clientProof: clientProof
        )

        guard let url = URL(string: "\(baseURL)/ecdh/confirm") else {
            completion(nil, NSError(domain: "EcdhClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try? JSONEncoder().encode(request)

        let task = session.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                completion(nil, error)
                return
            }

            guard let data = data else {
                completion(nil, NSError(domain: "EcdhClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data"]))
                return
            }

            Task { @MainActor in
                do {
                    print("ConfirmData: \(String(data: data, encoding: .utf8) ?? "")")
                    let response = try JSONDecoder().decode(EcdhConfirmResponse.self, from: data)
                    print("✓ /ecdh/confirm succeeded")
                    print("  Status: \(response.status)")
                    if let hmacKey = response.hmacKey {
                        print("  Server HMAC key: \(hmacKey)")
                    }
                    completion(response, nil)
                } catch {
                    completion(nil, error)
                }
            }
        }
        task.resume()
    }

    func currentHmacKey() -> Data? {
        hmacKey
    }

    func restoreSessionState(sessionId: String, hmacKey: Data) {
        self.sessionId = sessionId
        self.hmacKey = hmacKey
    }

    func clearSessionState() {
        clientPrivateKey = nil
        clientPublicKeyBytes = nil
        clientInitPublicKeyBytes = nil
        clientInitPublicKeyBase64 = nil
        clientNonceBytes = nil
        clientNonceBase64 = nil
        sessionId = nil
        serverPublicKeyBytes = nil
        serverPublicKeyBase64 = nil
        serverNonceBytes = nil
        serverNonceBase64 = nil
        hmacKey = nil
        selectedTranscript = nil
        transcriptLineSeparator = "\n"
        clientFinishLabel = "client-finish"
        serverFinishLabel = "server-finish"
    }
}
