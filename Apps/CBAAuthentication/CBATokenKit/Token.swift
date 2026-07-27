//
//  Token.swift
//  CBATokenKit
//
//  Created by Ashish Awasthi on 23/07/26.
//

import CryptoTokenKit
import Security

class Token: TKToken, TKTokenDelegate {

    /// The encoded TokenPayload passed by the host app. The private key is loaded LAZILY
    /// from this at signing time (so biometric credentials only prompt when actually signing).
    private(set) var configurationData: Data?

    /// Public key derived from the certificate (no auth needed) — used to answer `supports`.
    private(set) var publicKey: SecKey?

    private(set) var providerName: String?

    private(set) var certHash: String?

    convenience init(tokenDriver: TKTokenDriver,
                     instanceID: TKToken.InstanceID,
                     configurationData: Data?) {
        self.init(tokenDriver: tokenDriver, instanceID: instanceID)
        self.configurationData = configurationData
        publishCertificate(from: configurationData)
    }

    /// Publishes the PUBLIC cert + key handle. Decodes metadata only (no private key) so a
    /// biometric credential does NOT prompt the user just to publish.
    private func publishCertificate(from configurationData: Data?) {
        guard let data = configurationData else {
            NSLog("Token: configurationData missing")
            return
        }
        do {
            let payload = try TokenPayloadUtility.decode(data, loadPrivateKey: false)
            let cert = payload.certificate
            publicKey = SecCertificateCopyKey(cert)
            self.providerName = payload.providerName
            self.certHash = payload.certHash

            guard let certItem = TKTokenKeychainCertificate(certificate: cert, objectID: payload.certHash),
                  let keyItem = TKTokenKeychainKey(certificate: cert, objectID: payload.certHash) else {
                NSLog("Token: failed to build keychain items")
                return
            }
            keyItem.label = "CBA Client Key"
            keyItem.canSign = true
            keyItem.isSuitableForLogin = true
            keyItem.constraints = [NSNumber(value: TKTokenOperation.signData.rawValue): true]

            keychainContents?.fill(with: [certItem, keyItem])
        } catch {
            NSLog("Token: failed to decode payload — \(error.localizedDescription)")
        }
    }

    /// Loads the private key on demand (prompts biometrics/passcode for a
    /// user-interaction-required credential). Called at signing time.
    func loadPrivateKey() -> SecKey? {
        guard let data = configurationData else { return nil }
        return try? TokenPayloadUtility.readPrivateKey(from: data)
    }

    func createSession(_ token: TKToken) throws -> TKTokenSession {
        return TokenSession(token: self)
    }

}
