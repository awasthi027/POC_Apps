import Foundation
import CryptoKit

final class ProtectedRequestSigner {
    func sign(
        hmacKey: Data,
        sessionId: String,
        certDeviceId: String,
        method: String,
        path: String,
        timestampMillis: String,
        nonce: String
    ) -> String? {
        let canonical = [sessionId, certDeviceId, method, path, timestampMillis, nonce].joined(separator: "\n")
        guard let canonicalData = canonical.data(using: .utf8) else {
            return nil
        }

        let signature = HMAC<SHA256>.authenticationCode(
            for: canonicalData,
            using: SymmetricKey(data: hmacKey)
        )
        return Data(signature).base64EncodedString()
    }
}

