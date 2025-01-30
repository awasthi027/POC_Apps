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
                              fileName: String) -> String
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
        return self.getSubjectName
    }

    var issueDate: String? {
        return self.getStartDate
    }

    var expiryDate: String?  {
        return self.getExpiryDate
    }
    
    var certTypes: String?  {
        return self.getCertificateTypes
    }

    var certDecription: String? {
        return self.getCertificateDescription
    }

    func createP12Certificate(p12CertName: String,
                              certPassword: String,
                              subjectName: String,
                              fileName: String) -> String {
        return P12CertificateService.createP12Certificate(p12CertName: p12CertName,
                                    certPassword: certPassword,
                                   subjectName: subjectName,
                                   fileName: fileName)
    }

}
