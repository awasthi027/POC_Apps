//
//  OpenSSLWrapperTests.swift
//  CertsOpenSSL
//
//  Created by Ashish Awasthi on 21/02/25.
//


import Testing
@testable import CertsOpenSSL


struct OpenSSLWrapperTests {

    @Test func changeCertificatePassword() async throws  {
        let isValid = ContentViewModel.changeCertificatePassword(certificateName: Bundle.main.path(forResource: "Ashish", ofType: "p12")!,
                                                          password: "password",
                                                          newPassword: "password1")
        #expect(isValid == true)
    }

}
