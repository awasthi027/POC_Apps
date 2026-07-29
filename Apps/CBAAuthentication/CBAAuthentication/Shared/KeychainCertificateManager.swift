//
//  KeychainCertificateManager.swift
//  CBAAuthentication
//
//  Created by Ashish Awasthi on 22/07/26.
//

import Foundation
import Security

/// A singleton that imports a PKCS#12 (`.p12`) client certificate and persists the
/// resulting `SecIdentity` in the app's Keychain, so it can be reused across launches
/// and presented during client-certificate (CBA) authentication challenges.
final class KeychainCertificateManager {

    struct StoredIdentity: Identifiable {
        let id: String
        let label: String
        let commonName: String
        let certificate: SecCertificate?
    }

    /// Shared singleton instance.
    static let shared = KeychainCertificateManager()

    /// Keychain label used to tag and look up the stored identity.
    private let identityLabel = "com.cbaauthentication.clientIdentity"

    /// Private initializer to enforce singleton usage.
    private init() {}

    func bundleCertificateSecIdentity(p12Path: String = "badssl.com-client",
                                      password: String = "badssl.com") -> SecIdentity?{
        let url = Bundle.main.url(forResource: p12Path, withExtension: "p12")!
        let p12Data = try! Data(contentsOf: url)
        let options = [kSecImportExportPassphrase as String: password]
        var items: CFArray?
        let status = SecPKCS12Import(p12Data as CFData, options as CFDictionary, &items)

        guard status == errSecSuccess,
              let itemArray = items as? [[String: Any]],
              let firstItem = itemArray.first,
              let identity = firstItem[kSecImportItemIdentity as String] else {
            print("Failed to import p12")
            return nil
        }
       return (identity as! SecIdentity)
    }

    // MARK: - Import & Store

    /// Imports a `.p12` file's identity and stores it in the Keychain.
    /// - Parameters:
    ///   - p12Data: Raw bytes of the `.p12` file.
    ///   - password: Password protecting the `.p12`.
    /// - Returns: `true` if the identity was imported and stored successfully.
    @discardableResult
    func storeIdentity(from p12Data: Data,
                       password: String) -> Bool {
        let options = [kSecImportExportPassphrase as String: password]
        var items: CFArray?
        let importStatus = SecPKCS12Import(p12Data as CFData, options as CFDictionary, &items)

        guard importStatus == errSecSuccess,
              let itemArray = items as? [[String: Any]],
              let firstItem = itemArray.first,
              let identityRef = firstItem[kSecImportItemIdentity as String] else {
            print("KeychainCertificateManager: p12 import failed (status: \(importStatus))")
            return false
        }

        let identity = identityRef as! SecIdentity

        // Remove any previously stored identity with the same label to avoid duplicates.
        deleteIdentity()

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecValueRef as String: identity,
            kSecAttrLabel as String: identityLabel
        ]

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess || addStatus == errSecDuplicateItem else {
            print("KeychainCertificateManager: failed to store identity (status: \(addStatus))")
            return false
        }

        print("KeychainCertificateManager: identity stored in Keychain")
        return true
    }

    /// Convenience overload: imports a `.p12` bundled in the app.
    /// - Parameters:
    ///   - resource: The resource name (without extension).
    ///   - password: Password protecting the `.p12`.
    /// - Returns: `true` on success.
    @discardableResult
    func storeIdentity(fromBundleResource resource: String, password: String) -> Bool {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "p12"),
              let data = try? Data(contentsOf: url) else {
            print("KeychainCertificateManager: could not read bundled resource \(resource).p12")
            return false
        }
        return storeIdentity(from: data, password: password)
    }

    // MARK: - Retrieve

    /// Retrieves the previously stored `SecIdentity` from the Keychain.
    /// - Returns: The stored identity, or `nil` if none exists.
    func loadIdentity() -> SecIdentity? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: identityLabel,
            kSecReturnRef as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let item = result else {
            if status != errSecItemNotFound {
                print("KeychainCertificateManager: load failed (status: \(status))")
            }
            return nil
        }

        // Safe to force-cast since the query class is kSecClassIdentity.
        return (item as! SecIdentity)
    }

    /// Whether an identity is currently stored in the Keychain.
    var hasStoredIdentity: Bool {
        loadIdentity() != nil
    }

    /// Returns all identities in the app Keychain scope so UI can show what is available.
    func listStoredIdentities() -> [StoredIdentity] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecReturnRef as String: true,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            if status != errSecItemNotFound {
                print("KeychainCertificateManager: list failed (status: \(status))")
            }
            return []
        }

        guard let items = result as? [[String: Any]] else {
            return []
        }

        return items.compactMap { item in
            guard let identity = item[kSecValueRef as String] else {
                return nil
            }

            let label = (item[kSecAttrLabel as String] as? String) ?? "(no label)"
            let secIdentity = identity as! SecIdentity
            var certificate: SecCertificate?
            SecIdentityCopyCertificate(secIdentity, &certificate)
            let commonName = certificateCommonName(for: secIdentity)
            let identifier = "\(label)|\(commonName)"

            return StoredIdentity(id: identifier,
                                  label: label,
                                  commonName: commonName,
                                  certificate: certificate)
        }
    }

    private func certificateCommonName(for identity: SecIdentity) -> String {
        var certificate: SecCertificate?
        let status = SecIdentityCopyCertificate(identity, &certificate)
        guard status == errSecSuccess, let certificate else {
            return "(unknown subject)"
        }

        return SecCertificateCopySubjectSummary(certificate) as String? ?? "(unknown subject)"
    }

    // MARK: - Delete

    /// Removes the stored identity from the Keychain.
    /// - Returns: `true` if deleted or nothing existed to delete.
    @discardableResult
    func deleteIdentity() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: identityLabel
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

