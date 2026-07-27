//
//  TokenPayload.swift
//  Shared between CBAAuthentication (app) and CBATokenKit (extension)
//
//  IMPORTANT: In Xcode, add this file to the *Target Membership* of BOTH the app
//  target and the CBATokenKit extension target.
//

import Foundation
import Security
import CryptoKit

/// Describes a token credential shared between the app and the CryptoTokenKit extension.
///
/// - The app builds a `TokenPayload` and encodes it into the token's `configurationData`.
/// - The extension decodes the `configurationData` back into a `TokenPayload` and uses the
///   private key to sign during a TLS client-certificate challenge.
final class TokenPayload {
    /// Private key. May be embedded in the payload (no user interaction) or resolved from
    /// the biometric-protected shared keychain (user interaction required).
    var privateKey: SecKey?

    /// The public X.509 certificate.
    var certificate: SecCertificate

    /// SHA-256 hex hash of the certificate DER (used as a stable identifier / keychain tag).
    var certHash: String

    /// Provider-defined token types/capabilities (e.g. ["authentication", "signing"]).
    var tokenTypes: [String]

    /// Name of the provider that owns this credential.
    var providerName: String

    /// When true, the private key is stored under biometrics and requires Face ID / Touch ID
    /// or passcode to be read (and therefore to sign).
    var userInteractionRequired: Bool

    init(privateKey: SecKey? = nil,
         certificate: SecCertificate,
         tokenTypes: [String],
         providerName: String,
         userInteractionRequired: Bool = false) {
        self.privateKey = privateKey
        self.certificate = certificate
        self.certHash = TokenPayload.certificateHash(certificate)
        self.tokenTypes = tokenTypes
        self.providerName = providerName
        self.userInteractionRequired = userInteractionRequired
    }

    /// SHA-256 hex digest of the certificate's DER data (`SecCertificateCopyData`).
    static func certificateHash(_ certificate: SecCertificate) -> String {
        let der = SecCertificateCopyData(certificate) as Data
        let digest = SHA256.hash(data: der)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

