//
//  TokenSession.swift
//  CBATokenKit
//
//  Created by Ashish Awasthi on 23/07/26.
//

import CryptoTokenKit
import Security

class TokenSession: TKTokenSession, TKTokenSessionDelegate {

    // Algorithms a TLS 1.2 / 1.3 handshake may ask for. TLS signs a DIGEST (not a message),
    // and TLS 1.3 prefers RSA-PSS, so we advertise the common set.
    private static let candidateAlgorithms: [SecKeyAlgorithm] = [
        .rsaSignatureDigestPKCS1v15SHA256,
        .rsaSignatureDigestPKCS1v15SHA384,
        .rsaSignatureDigestPKCS1v15SHA512,
        .rsaSignatureDigestPKCS1v15SHA1,
        .rsaSignatureDigestPSSSHA256,
        .rsaSignatureDigestPSSSHA384,
        .rsaSignatureDigestPSSSHA512,
        .ecdsaSignatureDigestX962SHA256,
        .ecdsaSignatureDigestX962SHA384,
        .ecdsaSignatureDigestX962SHA512
    ]

    /// Our owning Token instance.
    private var cbaToken: Token? { token as? Token }

    /// Picks the concrete SecKeyAlgorithm the system requested. Uses the PUBLIC key so we do
    /// NOT prompt for biometrics during a capability check — the biometric/passcode prompt
    /// happens only when the private key is loaded at signing time.
    private func resolveAlgorithm(for requested: TKTokenKeyAlgorithm) -> SecKeyAlgorithm? {
        guard let publicKey = cbaToken?.publicKey else { return nil }
        for algorithm in Self.candidateAlgorithms
        where requested.isAlgorithm(algorithm) && SecKeyIsAlgorithmSupported(publicKey, .verify, algorithm) {
            return algorithm
        }
        for algorithm in Self.candidateAlgorithms
        where requested.supportsAlgorithm(algorithm) && SecKeyIsAlgorithmSupported(publicKey, .verify, algorithm) {
            return algorithm
        }
        return nil
    }

    func tokenSession(_ session: TKTokenSession, beginAuthFor operation: TKTokenOperation, constraint: Any) throws -> TKTokenAuthOperation {
        // User interaction (biometrics/passcode) is handled when loading the private key
        // from the biometric keychain, so no separate auth operation is needed here.
        return TKTokenAuthOperation()
    }
    
    func tokenSession(_ session: TKTokenSession, supports operation: TKTokenOperation, keyObjectID: Any, algorithm: TKTokenKeyAlgorithm) -> Bool {
        guard operation == .signData else { return false }
        return resolveAlgorithm(for: algorithm) != nil
    }
    
    func tokenSession(_ session: TKTokenSession, sign dataToSign: Data, keyObjectID: Any, algorithm: TKTokenKeyAlgorithm) throws -> Data {
        // 1. Map the requested TLS algorithm (checked against the public key — no prompt yet).
        guard let signingAlgorithm = resolveAlgorithm(for: algorithm) else {
            throw NSError(domain: TKErrorDomain, code: TKError.Code.badParameter.rawValue,
                          userInfo: [NSLocalizedDescriptionKey: "Unsupported signing algorithm"])
        }
        print("CBATokenKit: Request")
        // Check it Yubikey Certificate
        if let providerName = cbaToken?.providerName,
           providerName == "YubiKey",
            let certHash = cbaToken?.certHash {
            // we are using a YubiKey activation
            let signedData = try self.signWithYubiKey(dataToSign: dataToSign, algorithm: signingAlgorithm, keyObjectID: certHash)
            print("CBATokenKit: operation completed.")
            return signedData
        }

        // 2. Load the private key on demand. For a user-interaction-required credential this
        //    prompts Face ID / Touch ID / passcode (read from the biometric shared keychain).
        guard let key = cbaToken?.loadPrivateKey() else {
            throw NSError(domain: TKErrorDomain, code: TKError.Code.authenticationNeeded.rawValue, userInfo: nil)
        }

        // 3. Produce the signature the TLS handshake needs.
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(key, signingAlgorithm, dataToSign as CFData, &error) else {
            throw error?.takeRetainedValue() as Error?
                ?? NSError(domain: TKErrorDomain, code: TKError.Code.corruptedData.rawValue, userInfo: nil)
        }
        return signature as Data
    }
    
    func tokenSession(_ session: TKTokenSession, decrypt ciphertext: Data, keyObjectID: Any, algorithm: TKTokenKeyAlgorithm) throws -> Data {
        var plaintext: Data?
        
        // Insert code here to decrypt the ciphertext using the specified key and algorithm.
        plaintext = nil
        
        if let plaintext = plaintext {
            return plaintext
        } else {
            // If the operation failed for some reason, fill in an appropriate error like objectNotFound, corruptedData, etc.
            // Note that responding with TKErrorCodeAuthenticationNeeded will trigger user authentication after which the current operation will be re-attempted.
            throw NSError(domain: TKErrorDomain, code: TKError.Code.authenticationNeeded.rawValue, userInfo: nil)
        }
    }
    
    func tokenSession(_ session: TKTokenSession, performKeyExchange otherPartyPublicKeyData: Data, keyObjectID objectID: Any, algorithm: TKTokenKeyAlgorithm, parameters: TKTokenKeyExchangeParameters) throws -> Data {
        var secret: Data?
        
        // Insert code here to perform Diffie-Hellman style key exchange.
        secret = nil
        
        if let secret = secret {
            return secret
        } else {
            // If the operation failed for some reason, fill in an appropriate error like objectNotFound, corruptedData, etc.
            // Note that responding with TKErrorCodeAuthenticationNeeded will trigger user authentication after which the current operation will be re-attempted.
            throw NSError(domain: TKErrorDomain, code: TKError.Code.authenticationNeeded.rawValue, userInfo: nil)
        }
    }
}
