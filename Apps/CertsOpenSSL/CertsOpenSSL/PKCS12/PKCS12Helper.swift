//
//  PKCS12Helper.swift
//  CertsOpenSSL
//
//  Created by Ashish Awasthi on 31/01/25.
//

protocol CryptoOperationProtocol {
    func enCrypt(message: String) -> Data
    func deCrypt(data: Data) -> String
    func signMessage(message: String) -> Data
    func verifyMessage(signaure: NSData, message: String) -> Bool
}

class PKCS12Helper: AAPKCS12HelperService,
                    CryptoOperationProtocol {
    
    override init(p12CertPath: String,
                  certPassword: String) {
        super.init(p12CertPath: p12CertPath,
                   certPassword: certPassword)
    }

    func enCrypt(message: String) -> Data {
        return self.aaPKCS12Helper.encryptMessage(message)
    }
    
    func deCrypt(data: Data) -> String {
        return self.aaPKCS12Helper.decryptData(data)
    }

    func signMessage(message: String) -> Data {
        return self.aaPKCS12Helper.signMessage(message)
    }

    func verifyMessage(signaure: NSData,
                       message: String) -> Bool {
        return self.aaPKCS12Helper.verifySignature(signaure as Data,
                                                   message: message)
    }
}

