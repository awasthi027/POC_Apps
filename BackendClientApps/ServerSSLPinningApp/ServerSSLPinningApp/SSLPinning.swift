import CryptoKit
import Foundation
import Security

struct SSLPinningValidator {
    /// Pins are read from this store, keyed by host. Lets launch-time fetches
    /// take effect for subsequent connections.
    private let pinStore: PinStore

    init(pinStore: PinStore) {
        self.pinStore = pinStore
    }

    /// Whether the given host has any pins configured.
    func hasPins(forHost host: String) -> Bool {
        pinStore.hasPins(forHost: host)
    }

    /// Pins configured for a host, in `sha256/<base64>` format.
    func expectedPins(forHost host: String) -> [String] {
        Array(pinStore.pins(forHost: host)).sorted()
    }

    /// Validate the server trust against the pins stored for `host`.
    /// Matches either the certificate pin or the public-key (SPKI) pin.
    func isServerTrust(_ trust: SecTrust, trustedForHost host: String) -> Bool {
        let stored = pinStore.pins(forHost: host)
        guard !stored.isEmpty else { return false }
        return !Self.computePins(from: trust).isDisjoint(with: stored)
    }

    /// Pins the server actually presented (certificate + public-key), `sha256/<base64>`.
    func serverPins(for trust: SecTrust) -> [String] {
        Array(Self.computePins(from: trust)).sorted()
    }

    // MARK: - Pin computation

    /// Compute both certificate and public-key pins for every cert in the trust chain.
    static func computePins(from trust: SecTrust) -> Set<String> {
        var pins: Set<String> = []
        for certificate in certificates(from: trust) {
            pins.formUnion(Self.pins(for: certificate))
        }
        return pins
    }

    /// Compute both pins for a single certificate.
    static func pins(for certificate: SecCertificate) -> Set<String> {
        var pins: Set<String> = []
        let certData = SecCertificateCopyData(certificate) as Data
        pins.insert(pinString(forDigest: sha256Digest(for: certData)))
        if let spki = subjectPublicKeyInfo(for: certificate) {
            pins.insert(pinString(forDigest: sha256Digest(for: spki)))
        }
        return pins
    }

    /// Compute pins from raw DER certificate data (used to seed the store from a bundled cert).
    static func pins(forCertificateData data: Data) -> Set<String> {
        guard let der = derData(from: data),
              let certificate = SecCertificateCreateWithData(nil, der as CFData) else {
            return []
        }
        return Self.pins(for: certificate)
    }

    /// Accepts either DER or PEM certificate data and returns DER.
    static func derData(from data: Data) -> Data? {
        if let text = String(data: data, encoding: .utf8),
           text.contains("-----BEGIN CERTIFICATE-----") {
            let base64 = text
                .components(separatedBy: "-----BEGIN CERTIFICATE-----").last?
                .components(separatedBy: "-----END CERTIFICATE-----").first?
                .replacingOccurrences(of: "\r", with: "")
                .replacingOccurrences(of: "\n", with: "")
                .replacingOccurrences(of: " ", with: "") ?? ""
            return Data(base64Encoded: base64)
        }
        return data // assume already DER
    }

    private static func certificates(from trust: SecTrust) -> [SecCertificate] {
        if #available(iOS 15.0, *) {
            return (SecTrustCopyCertificateChain(trust) as? [SecCertificate]) ?? []
        } else {
            let count = SecTrustGetCertificateCount(trust)
            return (0..<count).compactMap { SecTrustGetCertificateAtIndex(trust, $0) }
        }
    }

    /// Rebuild SubjectPublicKeyInfo (SPKI) DER so the hash matches server-side
    /// `publicKey.getEncoded()` (X.509 SPKI).
    private static func subjectPublicKeyInfo(for certificate: SecCertificate) -> Data? {
        guard let publicKey = SecCertificateCopyKey(certificate),
              let keyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data?,
              let attributes = SecKeyCopyAttributes(publicKey) as? [CFString: Any] else {
            return nil
        }

        let keyType = attributes[kSecAttrKeyType] as? String
        let keySize = attributes[kSecAttrKeySizeInBits] as? Int
        guard let header = asn1Header(keyType: keyType, keySizeInBits: keySize) else {
            return nil
        }
        return header + keyData
    }

    /// ASN.1 SPKI headers by key type/size (same approach as TrustKit).
    private static func asn1Header(keyType: String?, keySizeInBits: Int?) -> Data? {
        let rsa = kSecAttrKeyTypeRSA as String
        let ec = kSecAttrKeyTypeECSECPrimeRandom as String

        switch (keyType, keySizeInBits) {
        case (rsa, 2048):
            return Data([0x30, 0x82, 0x01, 0x22, 0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86,
                         0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00, 0x03,
                         0x82, 0x01, 0x0f, 0x00])
        case (rsa, 4096):
            return Data([0x30, 0x82, 0x02, 0x22, 0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86,
                         0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00, 0x03,
                         0x82, 0x02, 0x0f, 0x00])
        case (ec, 256):
            return Data([0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce,
                         0x3d, 0x02, 0x01, 0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d,
                         0x03, 0x01, 0x07, 0x03, 0x42, 0x00])
        case (ec, 384):
            return Data([0x30, 0x76, 0x30, 0x10, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce,
                         0x3d, 0x02, 0x01, 0x06, 0x05, 0x2b, 0x81, 0x04, 0x00, 0x22,
                         0x03, 0x62, 0x00])
        default:
            return nil
        }
    }

    private static func sha256Digest(for data: Data) -> Data {
        Data(SHA256.hash(data: data))
    }

    private static func pinString(forDigest digest: Data) -> String {
        "sha256/" + digest.base64EncodedString()
    }
}

final class SSLPinningSessionDelegate: NSObject, URLSessionDelegate {
    private let validator: SSLPinningValidator

    /// Set when the most recent server-trust challenge failed pin validation.
    private(set) var lastFailure: (host: String, serverPins: [String], expectedPins: [String])?

    init(validator: SSLPinningValidator) {
        self.validator = validator
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let host = challenge.protectionSpace.host

        // No pins configured for this host -> fall back to system default evaluation.
        guard validator.hasPins(forHost: host) else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        if validator.isServerTrust(trust, trustedForHost: host) {
            lastFailure = nil
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            lastFailure = (
                host: host,
                serverPins: validator.serverPins(for: trust),
                expectedPins: validator.expectedPins(forHost: host)
            )
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}


