//
//  SecurityKeyPair.swift
//  Crypto-Native
//
//  Created by Ashish Awasthi on 04/02/25.
//

import Foundation

public class SecurityKeyPair {

    public var publicKey: SecKey? = nil
    public var privateKey: SecKey? = nil

    required public init(publicKey: SecKey?,
                         privateKey: SecKey?) {
        self.publicKey = publicKey
        self.privateKey = privateKey
    }

    public var isEmpty: Bool {
        return (publicKey == nil &&
                privateKey == nil)
    }

    public var areBothKeysAvailable: Bool {
        return (self.publicKey != nil &&
                self.privateKey != nil)
    }

    public var blockSize: Int {
        guard let keyPublic = self.publicKey else { return 0 }
        return SecKeyGetBlockSize(keyPublic)
    }
}

@frozen public enum AsymmetricCryptoType {
    case rsa
    case ecc

    var keyTypeAttribute: CFString {
        switch self {
        case .rsa:
            return kSecAttrKeyTypeRSA
        case .ecc:
                return kSecAttrKeyTypeECSECPrimeRandom
        }
    }
    var identifier: String {
        switch self {
        case .rsa:
            return "rsa"

        case .ecc:
            return "ecc"
        }
    }
    
    var keySize: UInt {
        switch self {
        case .rsa: return 2048
        case .ecc: return 256
        }
    }
}
