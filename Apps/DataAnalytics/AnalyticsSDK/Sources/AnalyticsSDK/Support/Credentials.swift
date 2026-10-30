import Foundation
import Security

/// Supplies the bearer token for uploads. The SDK never persists tokens itself; hosts either keep them in
/// memory, or use `KeychainCredentialProvider`.
public protocol CredentialProvider: Sendable {
    func currentToken() async -> String?
    /// Called once after a 401. Return a *new* token, or `nil` if refresh is unsupported. If the refreshed
    /// request still fails with 401 the SDK pauses uploads (events stay queued) until `credentialsDidChange()`.
    func refreshToken() async -> String?
}

public struct StaticCredentialProvider: CredentialProvider {
    private let token: String?
    public init(token: String?) { self.token = token }
    public func currentToken() async -> String? { token }
    public func refreshToken() async -> String? { nil }
}

/// Keychain-backed token storage. Uses `AfterFirstUnlockThisDeviceOnly` so background uploads work while the
/// device is locked, and the token never leaves the device through backups.
public final class KeychainCredentialProvider: CredentialProvider, @unchecked Sendable {
    private let service: String
    private let account: String
    private let refreshHandler: (@Sendable () async -> String?)?

    public init(service: String, account: String, refreshHandler: (@Sendable () async -> String?)? = nil) {
        self.service = service
        self.account = account
        self.refreshHandler = refreshHandler
    }

    public func save(token: String) throws {
        SecItemDelete(baseQuery() as CFDictionary)
        var add = baseQuery()
        add[kSecValueData as String] = Data(token.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw AnalyticsError.storageFailure(code: Int32(status)) }
    }

    public func deleteToken() { SecItemDelete(baseQuery() as CFDictionary) }

    public func currentToken() async -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func refreshToken() async -> String? {
        guard let token = await refreshHandler?() else { return nil }
        try? save(token: token)
        return token
    }

    private func baseQuery() -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }
}
