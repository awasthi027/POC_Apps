//
//  AAPKCS12HelperTest.swift
//  CertsOpenSSL
//
//  Created by Ashish Awasthi on 31/01/25.
//

import Testing
@testable import CertsOpenSSL


struct AAPKCS12HelperTest {

    @Test func encryptAndDecryptMessage() async throws {
        let viewModel = CryptoOperationViewModel.certificateAndPasswordViewModel()
        let message = "Message to encrypt and decrypt"
        let encryptedData = viewModel.cryptoOperation.enCrypt(message: message)
        #expect(encryptedData != nil)
        let decryptMessage = viewModel.cryptoOperation.deCrypt(data: encryptedData)
        #expect(decryptMessage == message)
    }

    @Test func verifySignature() async throws {
        let viewModel = CryptoOperationViewModel.certificateAndPasswordViewModel()
        let message = "Message to sign and verify"
        let signature = viewModel.cryptoOperation.signMessage(message: message)
        #expect(signature != nil)
        let verify = viewModel.cryptoOperation.verifyMessage(signaure: signature as NSData,
                                                                     message: message)
        #expect(verify == true)
    }

    @Test func changeCertificatePassword() async throws  {

    }

}
