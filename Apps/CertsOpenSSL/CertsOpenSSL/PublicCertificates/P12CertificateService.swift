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
    
    static func changeCertificatePassword(certName: String,
                                          certPassword: String,
                                          newPassword: String) -> Bool {
        let p12Data = OpenSSLWrapper.updatePKCS12Password(certName,
                                                          oldPassword: certPassword,
                                                          newPassword: newPassword)
        return OpenSSLWrapper.validatePKCS12Data(p12Data,
                                                 password: newPassword)
    }
}
