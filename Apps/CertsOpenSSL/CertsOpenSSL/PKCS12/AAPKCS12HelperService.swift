
//
//  Untitled.swift
//  CertsOpenSSL
//
//  Created by Ashish Awasthi on 31/01/25.
//

class AAPKCS12HelperService {

    var aaPKCS12Helper: AAPKCS12Helper

    init(p12CertPath: String,
         certPassword: String) {
        self.aaPKCS12Helper = AAPKCS12Helper(p12CertPath,
                                        certPassword: certPassword)
    }

}
