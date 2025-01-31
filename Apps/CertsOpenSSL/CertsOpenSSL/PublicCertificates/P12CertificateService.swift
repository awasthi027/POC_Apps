//
//  P12CertificateGenerator.swift
//  CertsOpenSSL
//
//  Created by Ashish Awasthi on 29/01/25.
//

import Foundation

public enum CertificateType: Int {
    case authentication
    case signing
    case encryption
    case historical
    case all
    case certsWithoutPurpose
}

public extension CertificateType {
    var stringValue: String {
        switch self {
        case .authentication: return "Authentication"
        case .signing: return "Signing"
        case .encryption: return "Encryption"
        case .historical:   return "Historical"
        case .all: return "Default"
        case .certsWithoutPurpose: return "CertsWithoutPurpose"
        }
    }

    static func certificateType(forStringValue stringValue: String) -> CertificateType? {
        switch stringValue {
        case "Authentication": return CertificateType.authentication
        case "Signing": return CertificateType.signing
        case "Encryption": return CertificateType.encryption
        case "Historical": return CertificateType.historical
        case "Default": return CertificateType.all
        case "CertsWithoutPurpose": return CertificateType.certsWithoutPurpose
        default:
            return nil
        }
    }
}

class P12CertificateService {

    var openSSLWrapper: OpenSSLWrapper

    init(p12CertPath: String,
         certPassword: String) {
        self.openSSLWrapper = OpenSSLWrapper(p12CertPath,
                                        certPassword: certPassword)
    }

    init(attributes: [AnyHashable : Any],
         publicKeyData: Data?) {
        var publicKey = publicKeyData
        if publicKeyData == nil {
            publicKey = OpenSSLWrapper.createPublicKeyAndPrivateKeyGetData().publicKey as Data
        }
        openSSLWrapper = OpenSSLWrapper(attributes: attributes,
                                        publicKey: publicKey)
    }

    static func createP12Certificate(p12CertName: String,
                                     certPassword: String,
                                     subjectName: String,
                                     email: String,
                                     fileName: String) -> String{
        return OpenSSLWrapper.generateP12Certificate(certPassword,
                                                     certName: p12CertName,
                                                     subjectName: subjectName,
                                                     email: email,
                                                     fileName: fileName)
    }

    var getSubjectName: String? {
        return self.openSSLWrapper.readSubjectNameFromCert()
    }

    var getStartDate: String? {
        return self.openSSLWrapper.readCertificateIssueDate()
    }

    var getExpiryDate: String? {
        return self.openSSLWrapper.readCertificateExpiryDate()
    }

    var getCertificateTypes: String {
        var types = [String]()
        if self.openSSLWrapper.hasExtendedUsage(ExtendedKeyUsage.SSL_Client) {
            types.append(CertificateType.authentication.stringValue)
        }

        if self.openSSLWrapper.canUse(for: KeyUsage.DigitalSignature) {
            types.append(CertificateType.signing.stringValue)
        }

        if self.openSSLWrapper.canUse(for: KeyUsage.DataEncipherment) || self.openSSLWrapper.canUse(for: KeyUsage.KeyEncipherment) {
            types.append(CertificateType.encryption.stringValue)
        }

        return types.joined(separator: ", ")
    }

    var getCertificateDescription: String {
        return self.openSSLWrapper.certDescription()
    }
}
