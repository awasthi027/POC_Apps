//
//  Untitled.swift
//  CertsOpenSSL
//
//  Created by Ashish Awasthi on 29/01/25.
//

class ContentViewModel: ObservableObject {

  static var certificatePath: String  = ""

    var certProtocol: CertificateParserProtocol

    init(certProtocol: CertificateParserProtocol) {
        self.certProtocol = certProtocol
    }

    func createP12Certificate(p12CertName: String,
                              certPassword: String,
                              subjectName: String,
                              email: String,
                              fileName: String) {
        Self.certificatePath = self.certProtocol.createP12Certificate(p12CertName: p12CertName,
                                                                      certPassword: certPassword,
                                                                      subjectName: subjectName,
                                                                      emailAddress: email,
                                                                      fileName: fileName)
    }

    func readCertificateDescription () -> String {
        return self.certProtocol.certDecription ?? ""
    }

}

extension ContentViewModel {

    static func certificateAndPasswordViewModel() ->ContentViewModel {
        var certPath = Self.certificatePath
        if  certPath == "" {
            certPath = Bundle.main.path(forResource: "Ashish", ofType: "p12")!
        }
        return ContentViewModel(certProtocol: CertificateHelper(p12CertPath: certPath,
                                                                certPassword: "password"))
    }

    // Create certificate attribues
    static func contentViewModelAttributesAndPublicKey() ->ContentViewModel {
        let attributes = ["AACertificateSubjectName": "X509Test", "AAUserID" : "Test User ID", "AAEmailId" : "myemail.awasthi@gmail.com"];
        return ContentViewModel(certProtocol: CertificateHelper(attributes: attributes, publicKeyData: nil) )
    }

}
