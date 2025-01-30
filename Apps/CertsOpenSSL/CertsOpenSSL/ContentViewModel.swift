//
//  Untitled.swift
//  CertsOpenSSL
//
//  Created by Ashish Awasthi on 29/01/25.
//

class ContentViewModel: ObservableObject {

    @Published var certSubjectName: String  = ""
    @Published var certStartDate: String  = ""
    @Published var certExpiryDate: String  = ""
    @Published var certTypes: String  = ""
   
    var certProtocol: CertificateParserProtocol

    init(certProtocol: CertificateParserProtocol) {
        self.certProtocol = certProtocol
    }

    func createP12Certificate(p12CertName: String,
                              certPassword: String,
                              subjectName: String,
                              fileName: String) -> String {
        return self.certProtocol.createP12Certificate(p12CertName: p12CertName,
                                                      certPassword: certPassword,
                                                      subjectName: subjectName,
                                                      fileName: fileName)
    }

    func readCertificateSubjectName() {
       self.certSubjectName = self.certProtocol.subjectName ?? ""
    }

    func readCertificateIssueDate() {
        self.certStartDate = self.certProtocol.issueDate ?? ""
    }

    func readCertificateExpiryDate () {
        self.certExpiryDate = self.certProtocol.expiryDate ?? ""
    }
    
    func readCertificateTypes () {
        self.certTypes = self.certProtocol.certTypes ?? ""
    }

    func readCertificateDescription () -> String {
        return self.certProtocol.certDecription ?? ""
    }

}

extension ContentViewModel {

    static func certificateAndPasswordViewModel() ->ContentViewModel {
        return ContentViewModel(certProtocol: CertificateHelper(p12CertPath: Bundle.main.path(forResource: "encryptionCert", ofType: "p12")!, certPassword: "entPKI2000"))
    }

    static func contentViewModelAttributesAndPublicKey() ->ContentViewModel {
        let attributes = ["AACertificateSubjectName": "X509Test", "AAUserID" : "Test User ID", "AAEmailId" : "myemail.awasthi@gmail.com"];
        return ContentViewModel(certProtocol: CertificateHelper(attributes: attributes, publicKeyData: nil) )
    }

}
