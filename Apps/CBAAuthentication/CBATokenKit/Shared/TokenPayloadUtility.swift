//
//  TokenPayloadUtility.swift
//  Shared between CBAAuthentication (app) and CBATokenKit (extension)
//
//  IMPORTANT:
//   1. Add this file to the *Target Membership* of BOTH the app and the CBATokenKit
//      extension target.
//   2. Both targets must list `biometricAccessGroup` in their keychain-access-groups
//      entitlement so the biometric-protected key can be shared.
//

import Foundation
import Security
import LocalAuthentication

enum TokenPayloadError: LocalizedError {
    case invalidPayload
    case missingPrivateKey
    case keychainError(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidPayload:          return "Invalid or corrupted token payload."
        case .missingPrivateKey:       return "Private key not available."
        case .keychainError(let s):    return "Keychain error \(s)."
        }
    }
}

/// Encodes/decodes a `TokenPayload` to/from `configurationData` and manages the
/// biometric-protected private key in a shared keychain group.
enum TokenPayloadUtility {

    /// Suffix of the shared keychain group (the part after the app-id prefix).
    /// Must match the `keychain-access-groups` entry `$(AppIdentifierPrefix)group.ashi.cbaauth`
    /// in BOTH targets' entitlements.
    static let sharedGroupSuffix = "group.ashi.cbaauth"

    private static var cachedAccessGroup: String?

    /// The full shared keychain access group, resolved at runtime so we always use the app's
    /// real app-id prefix (which may differ from the Team ID). This avoids -34018 caused by a
    /// hardcoded prefix that doesn't match what `$(AppIdentifierPrefix)` expands to.
    static var biometricAccessGroup: String {
        if let cached = cachedAccessGroup { return cached }
        let prefix = resolveAppIdentifierPrefix() ?? "S2ZMFGQM93"
        let group = "\(prefix).\(sharedGroupSuffix)"
        cachedAccessGroup = group
        NSLog("TokenPayloadUtility: using shared access group \(group)")
        return group
    }

    /// Reads the app's real keychain access-group prefix by probing the default group.
    private static func resolveAppIdentifierPrefix() -> String? {
        let account = "tokenpayload.prefix.probe"
        let service = "tokenpayload.prefix.probe"
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service
        ]

        var query = base
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        var status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            var addQuery = base
            addQuery[kSecReturnAttributes as String] = true
            status = SecItemAdd(addQuery as CFDictionary, &result)
        }
        guard status == errSecSuccess,
              let attrs = result as? [String: Any],
              let accessGroup = attrs[kSecAttrAccessGroup as String] as? String else {
            return nil
        }
        // Default group looks like "<prefix>.<bundle-id>" — the prefix is the first component.
        return accessGroup.components(separatedBy: ".").first
    }

    /// Service name for the biometric-protected key item.
    static let biometricService = "ashi.com.newLearning.CBAAuthentication.ctk.key"

    // Keys used inside the encoded JSON payload.
    private enum Key {
        static let certificate = "certificate"
        static let certHash = "certHash"
        static let tokenTypes = "tokenTypes"
        static let providerName = "providerName"
        static let userInteractionRequired = "userInteractionRequired"
        static let privateKey = "privateKey"
        static let keyType = "keyType"
        static let keySize = "keySize"
    }

    // MARK: - Encode

    /// Encodes the payload into `Data` suitable for `TKTokenConfiguration.configurationData`.
    ///
    /// - If `userInteractionRequired` is true, the private key DATA is written to the
    ///   biometric-protected shared keychain (keyed by `certHash`) and is NOT embedded.
    /// - Otherwise the private key data is embedded (base64) so the extension can sign silently.
    static func encode(_ payload: TokenPayload) throws -> Data {
        var dict: [String: Any] = [
            Key.certificate: (SecCertificateCopyData(payload.certificate) as Data).base64EncodedString(),
            Key.certHash: payload.certHash,
            Key.tokenTypes: payload.tokenTypes,
            Key.providerName: payload.providerName,
            Key.userInteractionRequired: payload.userInteractionRequired
        ]

        if let key = payload.privateKey {
            // Export the key data + attributes needed to reconstruct it later.
            guard let external = SecKeyCopyExternalRepresentation(key, nil) as Data?,
                  let attrs = SecKeyCopyAttributes(key) as? [String: Any],
                  let keyType = attrs[kSecAttrKeyType as String] as? String,
                  let keySize = attrs[kSecAttrKeySizeInBits as String] as? Int else {
                throw TokenPayloadError.missingPrivateKey
            }
            // keyType/keySize are not secret — always include them so decode can rebuild the key.
            dict[Key.keyType] = keyType
            dict[Key.keySize] = keySize

            if payload.userInteractionRequired {
                // Store the key DATA behind biometrics; do NOT embed it in the payload.
                try storeKeyDataUnderBiometrics(external, account: payload.certHash)
            } else {
                dict[Key.privateKey] = external.base64EncodedString()
            }
        } else if payload.userInteractionRequired {
            throw TokenPayloadError.missingPrivateKey
        }

        return try JSONSerialization.data(withJSONObject: dict, options: [])
    }

    // MARK: - Decode

    /// Decodes `configurationData` back into a `TokenPayload`.
    ///
    /// - Parameter loadPrivateKey: when true, resolves the private key (which, for a
    ///   biometric credential, prompts Face ID / Touch ID / passcode). Pass `false` when you
    ///   only need the certificate/metadata (e.g. to publish the cert) so you don't prompt
    ///   the user unnecessarily.
    static func decode(_ configurationData: Data, loadPrivateKey: Bool = true) throws -> TokenPayload {
        guard let dict = try JSONSerialization.jsonObject(with: configurationData) as? [String: Any],
              let certB64 = dict[Key.certificate] as? String,
              let certData = Data(base64Encoded: certB64),
              let certificate = SecCertificateCreateWithData(nil, certData as CFData),
              let providerName = dict[Key.providerName] as? String,
              let userInteractionRequired = dict[Key.userInteractionRequired] as? Bool else {
            throw TokenPayloadError.invalidPayload
        }
        let tokenTypes = dict[Key.tokenTypes] as? [String] ?? []

        let payload = TokenPayload(privateKey: nil,
                                   certificate: certificate,
                                   tokenTypes: tokenTypes,
                                   providerName: providerName,
                                   userInteractionRequired: userInteractionRequired)

        guard loadPrivateKey else { return payload }

        // keyType/keySize are needed to reconstruct the SecKey regardless of source.
        guard let keyType = dict[Key.keyType] as? String,
              let keySize = dict[Key.keySize] as? Int else {
            return payload
        }
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: keyType,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecAttrKeySizeInBits as String: keySize
        ]

        let keyData: Data?
        if userInteractionRequired {
            // Reading this triggers Face ID / Touch ID / passcode.
            keyData = try readKeyDataUnderBiometrics(
                account: payload.certHash,
                reason: "Authenticate to use the \(providerName) certificate")
        } else if let keyB64 = dict[Key.privateKey] as? String {
            keyData = Data(base64Encoded: keyB64)
        } else {
            keyData = nil
        }

        if let keyData {
            payload.privateKey = SecKeyCreateWithData(keyData as CFData, attributes as CFDictionary, nil)
        }

        return payload
    }

    /// Convenience: decode `configurationData` and return only the private key.
    static func readPrivateKey(from configurationData: Data) throws -> SecKey? {
        try decode(configurationData).privateKey
    }

    // MARK: - Biometric-protected shared keychain

    /// Stores the private key DATA protected by biometrics/passcode in the shared access group.
    /// Storing exported key DATA (kSecValueData) is far more reliable than persisting a
    /// SecKey ref (kSecValueRef), which frequently fails to add and later reads as -25300.
    static func storeKeyDataUnderBiometrics(_ keyData: Data, account: String) throws {
        // Replace any existing entry.
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: biometricService,
            kSecAttrAccount as String: account,
            kSecAttrAccessGroup as String: biometricAccessGroup
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        var acError: Unmanaged<CFError>?
        // Prefer biometrics: if the device has usable biometrics, require them (Face ID / Touch ID).
        // Only when biometrics are unavailable do we fall back to the device passcode.
        let probe = LAContext()
        let biometricsAvailable = probe.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        let flags: SecAccessControlCreateFlags = biometricsAvailable ? .biometryAny : .devicePasscode
        NSLog("TokenPayloadUtility: storing key with \(biometricsAvailable ? "biometryAny" : "devicePasscode")")
        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            flags,
            &acError) else {
            let err = acError!.takeRetainedValue()
            NSLog("TokenPayloadUtility: access control creation failed — \(err)")
            throw err as Error
        }

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: biometricService,
            kSecAttrAccount as String: account,
            kSecAttrAccessGroup as String: biometricAccessGroup,
            kSecValueData as String: keyData,
            kSecAttrAccessControl as String: access
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        NSLog("TokenPayloadUtility: store key data status \(status) (account \(account))")
        guard status == errSecSuccess else { throw TokenPayloadError.keychainError(status) }
    }

    /// Reads the private key DATA back, prompting the user for biometrics/passcode.
    static func readKeyDataUnderBiometrics(account: String, reason: String) throws -> Data {
        let context = LAContext()
        context.localizedReason = reason

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: biometricService,
            kSecAttrAccount as String: account,
            kSecAttrAccessGroup as String: biometricAccessGroup,
            kSecReturnData as String: true,
            kSecUseAuthenticationContext as String: context
        ]
        var out: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        NSLog("TokenPayloadUtility: read key data status \(status) (account \(account))")
        guard status == errSecSuccess, let data = out as? Data else {
            throw TokenPayloadError.keychainError(status)
        }
        return data
    }
}

