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
        let message = "Ashish"
        let encryptedData = viewModel.cryptoOperation.enCrypt(message: "Ashish")
        #expect(encryptedData != nil)
        let decryptMessage = viewModel.cryptoOperation.deCrypt(data: encryptedData)
        #expect(decryptMessage == message)
    }

}
