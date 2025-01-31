//
//  PKCS12Helper.swift
//  CertsOpenSSL
//
//  Created by Ashish Awasthi on 31/01/25.
//

protocol CryptoOperationProtocol {
    func enCrypt(message: String) -> Data
    func deCrypt(data: Data) -> String
}

class PKCS12Helper: AAPKCS12HelperService,
                    CryptoOperationProtocol {
    
    override init(p12CertPath: String,
                  certPassword: String) {
        super.init(p12CertPath: p12CertPath,
                   certPassword: certPassword)
    }

    func enCrypt(message: String) -> Data {
        self.aaPKCS12Helper.encryptMessage(message)
    }
    
    func deCrypt(data: Data) -> String {
        self.aaPKCS12Helper.decryptData(data)
    }

}

