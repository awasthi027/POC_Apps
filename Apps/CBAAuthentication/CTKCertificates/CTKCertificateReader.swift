//
//  CTKCertificateReader.swift
//  CTKCertificates
//
//  Reads certificates published by CryptoTokenKit persistent tokens, following the
//  euc-uem SampleashiTokenApp approach:
//    1. Enumerate available tokens with `TKTokenWatcher().tokenIDs`.
//    2. For each token, query the keychain SCOPED to that token via `kSecAttrTokenID`.
//
//  Note: the token publishes only the PUBLIC certificate + a key handle; the private key
//  stays inside the token extension. `hasPrivateKey` here means an identity (cert+key
//  handle) was returned, i.e. the key is usable for signing via the token.
//

import Foundation
import Security
import CryptoTokenKit

struct TokenCertificate: Identifiable {
    let id = UUID()
    let tokenID: String
    let commonName: String
    let serialNumber: String
    /// True when returned as an identity (cert + token-backed key handle).
    let hasPrivateKey: Bool
}

enum CTKCertificateReader {

    /// Reads certificates from every persistent token currently known to CryptoTokenKit.
    static func readFromPersistentTokens() -> [TokenCertificate] {
        let tokenIDs = TKTokenWatcher().tokenIDs
        var results: [TokenCertificate] = []
        for tokenID in tokenIDs {
            results.append(contentsOf: identities(forTokenID: tokenID))
            results.append(contentsOf: certificatesOnly(forTokenID: tokenID))
        }
        return results
    }

    // MARK: - Per-token queries (scoped with kSecAttrTokenID)

    /// Identities (certificate + token-backed private-key handle) for a specific token.
    private static func identities(forTokenID tokenID: String) -> [TokenCertificate] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrTokenID as String: tokenID,
            kSecReturnRef as String: true,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let items = result as? [[String: Any]] else {
            return []
        }
        return items.compactMap { attrs in
            guard let ref = attrs[kSecValueRef as String] else { return nil }
            let identity = ref as! SecIdentity
            var cert: SecCertificate?
            guard SecIdentityCopyCertificate(identity, &cert) == errSecSuccess, let cert else { return nil }
            return makeInfo(cert: cert, tokenID: tokenID, hasPrivateKey: true)
        }
    }

    /// Certificates (public only) for a specific token.
    private static func certificatesOnly(forTokenID tokenID: String) -> [TokenCertificate] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrTokenID as String: tokenID,
            kSecReturnRef as String: true,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let items = result as? [[String: Any]] else {
            return []
        }
        return items.compactMap { attrs in
            guard let ref = attrs[kSecValueRef as String] else { return nil }
            let cert = ref as! SecCertificate
            return makeInfo(cert: cert, tokenID: tokenID, hasPrivateKey: false)
        }
    }

    // MARK: - Helpers

    private static func makeInfo(cert: SecCertificate,
                                 tokenID: String,
                                 hasPrivateKey: Bool) -> TokenCertificate {
        let commonName = (SecCertificateCopySubjectSummary(cert) as String?) ?? "Unknown"

        var serial = "—"
        if let serialData = SecCertificateCopySerialNumberData(cert, nil) as Data? {
            serial = serialData.map { String(format: "%02x", $0) }.joined()
        }

        return TokenCertificate(tokenID: tokenID,
                                commonName: commonName,
                                serialNumber: serial,
                                hasPrivateKey: hasPrivateKey)
    }
}

