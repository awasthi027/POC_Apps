//
//  CertificateHelper.swift
//  CertsOpenSSL
//
//  Created by Ashish Awasthi on 30/01/25.
//

protocol CertificateParserProtocol {

    var subjectName: String? { get }
    var issueDate: String? { get}
    var expiryDate: String? { get }
    var certTypes: String? { get }
    var certDecription: String? { get }
    func createP12Certificate(p12CertName: String,
                              certPassword: String,
                              subjectName: String,
                              emailAddress: String,
                              fileName: String) -> String

    static func changeCertificatePassword(certificateName: String,
                                   password: String, newPassword: String) -> Bool
}


class CertificateHelper: P12CertificateService,
                         CertificateParserProtocol {

    override init(p12CertPath: String,
                  certPassword: String) {
        super.init(p12CertPath: p12CertPath,
                   certPassword: certPassword)
    }

    override init(attributes: [AnyHashable : Any],
                  publicKeyData: Data?) {
        super.init(attributes: attributes,
                   publicKeyData: publicKeyData)
    }

    var subjectName: String? {
        return self.openSSLWrapper.readSubjectNameFromCert()
    }

    var issueDate: String? {
        return self.openSSLWrapper.readCertificateIssueDate()
    }

    var expiryDate: String?  {
        return self.openSSLWrapper.readCertificateExpiryDate()
    }

    var certDecription: String? {
        return self.openSSLWrapper.certDescription()
    }

    var certTypes: String?  {
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

    func createP12Certificate(p12CertName: String,
                              certPassword: String,
                              subjectName: String,
                              emailAddress: String,
                              fileName: String) -> String {
        return P12CertificateService.createP12Certificate(p12CertName: p12CertName,
                                                          certPassword: certPassword,
                                                          subjectName: subjectName,
                                                          email: emailAddress,
                                                          fileName: fileName)
    }

    static func changeCertificatePassword(certificateName: String,
                                   password: String,
                                   newPassword: String) -> Bool {
        return P12CertificateService.changeCertificatePassword(certName: certificateName,
                                                               certPassword: password,
                                                               newPassword: newPassword)
    }

}
