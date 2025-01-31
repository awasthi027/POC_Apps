//
//  CryptoOperationViewModel.swift
//  CertsOpenSSL
//
//  Created by Ashish Awasthi on 31/01/25.
//


class CryptoOperationViewModel: ObservableObject {

    var cryptoOperation: CryptoOperationProtocol

    init(cryptoOperation: CryptoOperationProtocol) {
        self.cryptoOperation = cryptoOperation
    }
}

extension CryptoOperationViewModel {

    static func certificateAndPasswordViewModel() ->CryptoOperationViewModel {
        return CryptoOperationViewModel(cryptoOperation: PKCS12Helper(p12CertPath: Bundle.main.path(forResource: "Ashish", ofType: "p12")!, certPassword: "password"))
    }

}
