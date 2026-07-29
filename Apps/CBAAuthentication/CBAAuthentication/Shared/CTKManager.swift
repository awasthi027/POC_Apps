//
//  CTKCertificateBridge.swift
//  CBAAuthentication
//
//  App-side publisher. Registers a CryptoTokenKit persistent token so Safari /
//  ASWebAuthenticationSession (any process) can use the client certificate for an
//  mTLS challenge.
//
//  What gets stored where:
//   - PUBLIC certificate  -> published into the system keychain (TKTokenKeychainCertificate).
//   - Private key         -> NOT placed in the keychain. The p12 is handed to the extension
//                            via `configurationData`; the extension holds the SecKey and signs
//                            on demand (TKTokenSession). The published TKTokenKeychainKey is a
//                            public-key HANDLE only.
//
//  A CryptoTokenKit extension (CBATokenKit) is REQUIRED: it performs the TLS signature.
//

import Foundation
import Security
import CryptoTokenKit

final class CTKManager {
    static let shared = CTKManager()

    // Must match `com.apple.ctk.class-id` in CBATokenKit/Info.plist.
    private let tokenClassID: TKTokenDriver.ClassID = "ashi.com.newLearning.CBAAuthentication.CBATokenKit"
    private let tokenInstancePrefix = "cba-token-instance"


    private init() {}

    // MARK: - Public entry points

    @discardableResult
    func publishBundledCertificateToCTK(resource: String,
                                        password: String,
                                        userInteractionRequired: Bool = false) -> Bool {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "p12"),
              let data = try? Data(contentsOf: url) else {
            print("CTKCertificateBridge: missing bundled p12 \(resource).p12")
            return false
        }
        return publishCertificateToCTK(p12Data: data,
                                       password: password,
                                       userInteractionRequired: userInteractionRequired)
    }

    /// Imports the p12, then registers the persistent token: publishes the public cert +
    /// key handle and hands a `TokenPayload` to the extension via configurationData.
    @discardableResult
    func publishCertificateToCTK(p12Data: Data,
                                 password: String,
                                 userInteractionRequired: Bool = false) -> Bool {


        var imported: CFArray?
        let status = SecPKCS12Import(
            p12Data as CFData,
            [kSecImportExportPassphrase as String: password] as CFDictionary,
            &imported
        )
        guard status == errSecSuccess,
              let items = imported as? [[String: Any]],
              let first = items.first,
              let identityRef = first[kSecImportItemIdentity as String] else {
            print("CTKManager: invalid p12, import status \(status)")
            return false
        }
        let identity = identityRef as! SecIdentity

        var certificate: SecCertificate?
        guard SecIdentityCopyCertificate(identity, &certificate) == errSecSuccess,
              let certificate else {
            print("CTKManager: failed to copy certificate from identity")
            return false
        }
        let certHash = TokenPayload.certificateHash(certificate)
        if self.isTokenPresentInCtkStore(tokenId: certHash) {
            print("CTKManager: certificate already installed in CTK — skipping re-write.")
            return false
        }
        var privateKey: SecKey?
        SecIdentityCopyPrivateKey(identity, &privateKey)

        // Build the shared payload and encode it into configurationData.
        let tokenPayload = TokenPayload(privateKey: privateKey,
                                        certificate: certificate,
                                        tokenTypes: ["authentication"],
                                        providerName: "BadSSL",
                                        userInteractionRequired: userInteractionRequired)
        return registerTokenConfiguration(certificate: certificate, payload: tokenPayload)
    }

    func publishAccessoryCertificateToCTK(certificate: SecCertificate) -> Bool {
        // Build the shared payload and encode it into configurationData.
        let tokenPayload = TokenPayload(certificate: certificate,
                                        tokenTypes: ["authentication"],
                                        providerName: "YubiKey")
        return registerTokenConfiguration(certificate: certificate, payload: tokenPayload)
    }



    // MARK: - Diagnostics

    var isHostingAppForToken: Bool {
        TKTokenDriver.Configuration.driverConfigurations[tokenClassID] != nil
    }

    /// True when our token configuration is already registered WITH keychain items,
    /// i.e. the certificate has already been written to CTK.
    var isCertificateInstalled: Bool {
        guard let driverConfig = TKTokenDriver.Configuration.driverConfigurations[tokenClassID] else {
            return false
        }
        return driverConfig.tokenConfigurations.values.contains { !$0.keychainItems.isEmpty }
    }

    func publishDiagnostics() -> String {
        var lines: [String] = []
        lines.append("Hosting app for token: \(isHostingAppForToken ? "YES" : "NO — extension not embedded/signed")")

        let liveTokens = TKTokenWatcher().tokenIDs
        lines.append("Live CTK tokens (\(liveTokens.count)): \(liveTokens.isEmpty ? "none" : liveTokens.joined(separator: ", "))")

        let certs = countAndStatus(for: kSecClassCertificate)
        let ids = countAndStatus(for: kSecClassIdentity)
        lines.append("Our token certificates: \(certs.count) (status \(certs.status))")
        lines.append("Our token identities: \(ids.count) (status \(ids.status))")
        lines.append("(status 0 = success, -25300 = itemNotFound/empty, -34018 = missingEntitlement)")

        let text = lines.joined(separator: "\n")
        print("CTKManager diagnostics:\n\(text)")
        return text
    }

    /// Reads items belonging to OUR token, scoped by `kSecAttrTokenID` (the   way).
    /// We must NOT specify the `com.apple.token` access group here — doing so returns
    /// -34018 (missingEntitlement). Scoping by token ID avoids that.
    private func countAndStatus(for secClass: CFString) -> (count: Int, status: OSStatus) {
        guard let driverConfig = TKTokenDriver.Configuration.driverConfigurations[tokenClassID] else {
            return (0, errSecItemNotFound)
        }

        let instanceIDs = Array(driverConfig.tokenConfigurations.keys)
        guard !instanceIDs.isEmpty else {
            return (0, errSecItemNotFound)
        }

        var totalCount = 0
        var finalStatus: OSStatus = errSecItemNotFound

        for instanceID in instanceIDs {
            let fullTokenID = "\(tokenClassID):\(instanceID)"
            let query: [String: Any] = [
                kSecClass as String: secClass,
                kSecAttrTokenID as String: fullTokenID,
                kSecMatchLimit as String: kSecMatchLimitAll,
                kSecReturnAttributes as String: true,
                kSecReturnRef as String: true
            ]

            var result: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            if status == errSecSuccess {
                totalCount += (result as? [[String: Any]])?.count ?? 0
                finalStatus = errSecSuccess
            } else if finalStatus != errSecSuccess, finalStatus == errSecItemNotFound {
                finalStatus = status
            }
        }

        return (totalCount, finalStatus)
    }

    // MARK: - Persistent-token registration

    private func registerTokenConfiguration(certificate: SecCertificate,
                                            payload: TokenPayload) -> Bool {
        let configurationData: Data
        do {
            configurationData = try TokenPayloadUtility.encode(payload)
        } catch {
            print("CTKManager: failed to encode payload — \(error.localizedDescription)")
            return false
        }

        guard let driverConfig = TKTokenDriver.Configuration.driverConfigurations[tokenClassID] else {
            print("""
                        CTKManager: no driver configuration for class-id '\(tokenClassID)'.
            Ensure the CBATokenKit extension is embedded in this app, its Info.plist
            'com.apple.ctk.class-id' matches, and both are code-signed. Run on a real device.
            """)
            return false
        }
        let tokenInstanceID = tokenInstanceID(for: payload.certHash)
        // Re-register only this certificate's instance; other installed tokens are kept.
        driverConfig.removeTokenConfiguration(for: tokenInstanceID)
        let tokenConfig = driverConfig.addTokenConfiguration(for: tokenInstanceID)
        tokenConfig.configurationData = configurationData

        guard let certItem = TKTokenKeychainCertificate(certificate: certificate, objectID: payload.certHash),
              let keyItem = TKTokenKeychainKey(certificate: certificate, objectID: payload.certHash) else {
            print("CTKManager: failed to build keychain items")
            return false
        }
        keyItem.label = "CBA Client Key"
        keyItem.canSign = true
        keyItem.canDecrypt = false
        keyItem.canPerformKeyExchange = false
        keyItem.isSuitableForLogin = true
        keyItem.constraints = [NSNumber(value: TKTokenOperation.signData.rawValue): true]

        tokenConfig.keychainItems = [certItem, keyItem]
        print("CTKManager: registered token config (instance \(tokenInstanceID)).")
        return true
    }

    func isTokenPresentInCtkStore(tokenId: String) -> Bool {
        let existingTokens = self.currentTokenKeys()
        let instanceID = tokenInstanceID(for: tokenId)
        return existingTokens.contains(instanceID)
    }

    func currentTokenKeys() -> [String] {
        var theTokenKeys: [String] = []

        let driverConfigurations = TKTokenDriver.Configuration.driverConfigurations
        if let tokenDriverConfiguration = driverConfigurations[tokenClassID] {

            let tokenConfigurationDict = tokenDriverConfiguration.tokenConfigurations
            theTokenKeys = [String](tokenConfigurationDict.keys)
        }
        return theTokenKeys
    }

    private func tokenInstanceID(for certHash: String) -> TKToken.InstanceID {
        "\(tokenInstancePrefix)-\(certHash)"
    }
}

// MARK: - Clear token from CTK
extension CTKManager {

    /// Removes the published token identity.
    func unpublishCertificateFromCTK() {
        _ = clearAllTokensAndPrivateKeys()
    }

    /// Removes ALL token configurations our app has registered (e.g. stale
    /// `demo-token-instance-01` and the current `cba-token-instance-01`).
    /// System tokens (com.apple.setoken, com.apple.secelemtoken, …) are owned by iOS
    /// and cannot be removed.
    @discardableResult
    func removeAllOurTokenConfigurations() -> [String] {
        guard let driverConfig = TKTokenDriver.Configuration.driverConfigurations[tokenClassID] else {
            print("CTKManager: not the hosting app / no driver configuration.")
            return []
        }
        let instanceIDs = Array(driverConfig.tokenConfigurations.keys)
        for instanceID in instanceIDs {
            driverConfig.removeTokenConfiguration(for: instanceID)
            print("CTKManager: removed token configuration '\(instanceID)'")
        }
        return instanceIDs.map { "\($0)" }
    }

    /// Public API: clears one token configuration and its associated private key.
    /// - Parameter certHash: certificate hash used as objectID/account for the token key.
    /// - Returns: true if the private key was deleted or did not exist.
    @discardableResult
    func clearTokenAndPrivateKey(certHash: String) -> Bool {
        guard let driverConfig = TKTokenDriver.Configuration.driverConfigurations[tokenClassID] else {
            print("CTKManager: not the hosting app / no driver configuration.")
            return false
        }

        let instanceID = tokenInstanceID(for: certHash)
        driverConfig.removeTokenConfiguration(for: instanceID)
        print("CTKManager: removed token configuration '\(instanceID)'")

        let keyDeleted = TokenPayloadUtility.deleteKeyDataUnderBiometrics(account: certHash)
        if !keyDeleted {
            print("CTKManager: failed to delete private key for cert hash '\(certHash)'")
        }
        return keyDeleted
    }

    /// Public API: clears all app-managed token configurations and all associated private keys.
    /// - Returns: instance IDs removed from CTK.
    @discardableResult
    func clearAllTokensAndPrivateKeys() -> [String] {
        let removed = removeAllOurTokenConfigurations()
        if !TokenPayloadUtility.deleteAllKeyDataUnderBiometrics() {
            print("CTKManager: failed deleting one or more private keys from shared keychain")
        }
        return removed
    }
}

// MARK: - Generic CTK identity selection

extension CTKManager {

    /// Enumerates ALL token-backed identities (any provider app) and picks one whose issuer
    /// is in the server's accepted CA list. Falls back to the first token identity if the
    /// server did not send an issuer list.
    public func selectTokenIdentity(for challenge: URLAuthenticationChallenge) -> (SecIdentity, String)? {
        let acceptedIssuers = challenge.protectionSpace.distinguishedNames ?? []

        let query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrAccessGroup as String: kSecAttrAccessGroupToken as String,   // com.apple.token
            kSecReturnRef as String: true,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let items = result as? [[String: Any]] else {
            print("CTKManager: token identity search failed, status \(status)")
            return nil
        }

        var firstTokenIdentity: (SecIdentity, String)?

        for item in items {
            guard let ref = item[kSecValueRef as String] else { continue }
            let identity = ref as! SecIdentity
            let tokenID = (item[kSecAttrTokenID as String] as? String) ?? "unknown"

            if firstTokenIdentity == nil {
                firstTokenIdentity = (identity, tokenID)
            }

            // No issuer restriction from the server → any token identity is acceptable.
            if acceptedIssuers.isEmpty {
                return (identity, tokenID)
            }

            // Otherwise only offer an identity whose issuer the server accepts.
            if let certificate = copyCertificate(from: identity),
               issuerIsAccepted(certificate, acceptedIssuers: acceptedIssuers) {
                return (identity, tokenID)
            }
        }

        // Server sent issuers but none matched — fall back to the first token identity so the
        // owning token can still attempt the handshake.
        return firstTokenIdentity
    }

    private func copyCertificate(from identity: SecIdentity) -> SecCertificate? {
        var certificate: SecCertificate?
        guard SecIdentityCopyCertificate(identity, &certificate) == errSecSuccess else { return nil }
        return certificate
    }

    /// True if the certificate's issuer is one of the server's accepted CA names.
    private func issuerIsAccepted(_ certificate: SecCertificate, acceptedIssuers: [Data]) -> Bool {
        guard let issuer = SecCertificateCopyNormalizedIssuerSequence(certificate) as Data? else {
            return false
        }
        return acceptedIssuers.contains(issuer)
    }
}
