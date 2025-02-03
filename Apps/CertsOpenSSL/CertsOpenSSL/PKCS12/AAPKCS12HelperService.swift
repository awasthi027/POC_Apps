
//
//  Untitled.swift
//  CertsOpenSSL
//
//  Created by Ashish Awasthi on 31/01/25.
//

class AAPKCS12HelperService {

    var aaPKCS12Helper: AAPKCS12

    init(p12CertPath: String,
         certPassword: String) {
        self.aaPKCS12Helper = AAPKCS12(p12CertPath,
                                        certPassword: certPassword)
    }

}
