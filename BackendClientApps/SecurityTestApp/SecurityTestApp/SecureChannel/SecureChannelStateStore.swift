import Foundation

struct PersistedSecureChannelState: Codable {
    let sessionId: String
    let hmacKeyBase64: String
    let isSecureChannelComplete: Bool
    let isSecureChannelActive: Bool
}

final class SecureChannelStateStore {
    static let shared = SecureChannelStateStore()

    private let defaults: UserDefaults
    private let storageKey = "secure-channel-state"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> PersistedSecureChannelState? {
        guard let data = defaults.data(forKey: storageKey) else {
            return nil
        }

        return try? JSONDecoder().decode(PersistedSecureChannelState.self, from: data)
    }

    func save(sessionId: String, hmacKey: Data, isSecureChannelComplete: Bool, isSecureChannelActive: Bool) {
        let state = PersistedSecureChannelState(
            sessionId: sessionId,
            hmacKeyBase64: hmacKey.base64EncodedString(),
            isSecureChannelComplete: isSecureChannelComplete,
            isSecureChannelActive: isSecureChannelActive
        )

        guard let data = try? JSONEncoder().encode(state) else {
            return
        }

        defaults.set(data, forKey: storageKey)
    }

    func clear() {
        defaults.removeObject(forKey: storageKey)
    }
}

