//
//  AccessoryDetails.swift
//  CBAAuthentication
//
//  Created by Ashish Awasthi on 24/07/26.
//

import Foundation

class AccessoryCertsAndInfo {

    @Persist(key: "authenticationCert", defaultValue: nil)
    var authenticationCert: Data?

    @Persist(key: "encryptionCert", defaultValue: nil)
    var encryptionCert: Data?

    @Persist(key: "signingCert", defaultValue: nil)
    var signingCert: Data?

    @Persist(key: "yubiKeySerialNumber", defaultValue: 0)
    var yubiKeySerialNumber: Int32
}

