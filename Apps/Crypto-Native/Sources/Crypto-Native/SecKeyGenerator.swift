//
//  SecKeyGenerator.swift
//  Crypto-Native
//
//  Created by Ashish Awasthi on 03/02/25.
//
import Foundation

internal protocol SecKeySecurityProviderProtocol {
    var cryptoType: AsymmetricCryptoType { get }
    var keyPair: SecurityKeyPair { get }
    func encrypt(key: Smaug) throws -> Data
    func decrypt(data: Data) throws -> Smaug
}

internal protocol SecKeyGenerationProtocol {
    func harwareSecuredKeyPair(identifier: String) throws -> SecKeySecurityProviderProtocol
    func rsaKeyPair(identifier: String, keySize: UInt) throws -> SecKeySecurityProviderProtocol
    func loadKeyPair(identifier: String, cryptoType: AsymmetricCryptoType) throws -> SecKeySecurityProviderProtocol
    func clearKeyPair(identifier: String, cryptoType: AsymmetricCryptoType)
}

extension SecKeyGenerationProtocol {
    func harwareSecuredKeyPair(identifier: String) throws -> SecKeySecurityProviderProtocol {

        do {
            let keyPair = try SecurityKeyPair.generateHardwareSecuredKeyPair(size: AsymmetricCryptoType.ecc.keySize,
                                                                   identifier: identifier,
                                                                   cryptoType: .ecc)
            // we make sure the keyPair is persistence as this cannot be tested via unit test
           // let keyPair = try SecurityKeyPair.getKeyPair(identifier: identifier, cryptoType: .ecc)
            return SecKeySecurityProvider(crypto: .ecc, keyPair: keyPair)

        } 
        catch let error {
            // errSecUnimplemented is returned for unsupported devices, CryptoKit returns errSecNotAvailable for simulator
            guard  error._code == errSecUnimplemented || error._code == errSecNotAvailable  else {
                throw  RuntimeError("failedToGenerateKeyPair")
            }
            throw RuntimeError("hardwareSecuredKeyPairNotSupported")

        }
    }

    func rsaKeyPair(identifier: String,
                    keySize: UInt = AsymmetricCryptoType.rsa.keySize) throws -> SecKeySecurityProviderProtocol {
        // 2048, 3072, 4096
        let keyPair = try SecurityKeyPair.generateKeyPair(size: keySize,
                                                          identifier: identifier,
                                                          cryptoType: .rsa,
                                                          persistent: true)
        return SecKeySecurityProvider(crypto: .rsa,
                                      keyPair: keyPair)
    }

    func loadKeyPair(identifier: String,
                     cryptoType: AsymmetricCryptoType) throws -> SecKeySecurityProviderProtocol {

        let keyPair = try SecurityKeyPair.getKeyPair(identifier: identifier,
                                                     cryptoType: cryptoType)
        return SecKeySecurityProvider(crypto: cryptoType, keyPair: keyPair)
    }

    func clearKeyPair(identifier: String,
                      cryptoType: AsymmetricCryptoType) {
        _ = SecurityKeyPair.clearKeyPair(identifier: identifier, cryptoType: cryptoType)
    }
}

extension SecKeySecurityProviderProtocol {

    // For RSA, we cannot use AsymmetricKeyCryptor as it uses different encryption algorithm
    // we need to use type PKCS1 as it is compatible with iOS9
    func encrypt(key: Smaug) throws -> Data {
        switch self.cryptoType {
        case .ecc:
            let cryptor = AsymmetricKeyCryptor(keyPair: self.keyPair,
                                               cryptoType: .ecc)
            return try cryptor.encryptKey(rawKey: key)

        case .rsa:
            guard let publicKey = self.keyPair.publicKey else {
                throw RuntimeError("publicKeyIsUnavailable")
            }
            return try AsymmetricKeyCryptor.encryptKey(rawKey: key,
                                                       publicKey: publicKey,
                                                       algorithm: .rsaEncryptionPKCS1)
        }
    }

    func decrypt(data: Data) throws -> Smaug {
        guard self.isEncryptedData(data) else {
            throw RuntimeError("Data is not encrypted")
        }
        switch self.cryptoType {
        case .ecc:
            let cryptor = AsymmetricKeyCryptor(keyPair: self.keyPair, cryptoType: .ecc)
            return try cryptor.decryptKey(encryptedKeyData: data)

        case .rsa:
            guard let privateKey = self.keyPair.privateKey else {
                throw RuntimeError("privateKeyIsUnavailable")
            }
            return try AsymmetricKeyCryptor.decryptKey(encryptedKeyData: data, privateKey: privateKey, algorithm: .rsaEncryptionPKCS1)
        }
    }

    func isEncryptedData(_ data: Data) -> Bool {
        // Check if data length is less than 20 bytes
        return data.count == 256
    }
}


extension SecurityKeyPair {

    public static let allowedHardwareSecuredKeySizes: [UInt] = [256]

    /// Generates public/private key pair in secure enclave using accesssible attribute
    /// `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. Currently iOS supports only 256 bit keys with elliptic curve cryptography
    /// for secure enclave. Ref: [Apple docs]
    ///https://developer.apple.com/documentation/security/certificate_key_and_trust_services/keys/storing_keys_in_the_secure_enclave
    /// The key pair generated is persisted on device
    /// Please note that this method will first clear key pair generated with the passed identifier.
    ///
    /// - Parameters:
    ///   - size: keySize in bits to generate, **256** is the only currently supported size
    ///   - identifier: unique identifier that maps to the key pair
    ///   - cryptoType: type of key pair to be generated
    /// - Returns: generated key pair on success
    /// - Throws: error defined by `AWError.SDK.CryptoKit.AsymmetricCryptoPair`
    public static func generateHardwareSecuredKeyPair(size: UInt, identifier: String,
                                                      cryptoType: AsymmetricCryptoType) throws -> SecurityKeyPair {

        guard SecurityKeyPair.allowedHardwareSecuredKeySizes.contains(size) else {
            throw RuntimeError("keySizeNotSupported")
        }

        guard cryptoType == .ecc else {
            throw RuntimeError("cryptoTypeNotSupported")
        }

        _ = self.clearKeyPair(identifier: identifier, cryptoType: cryptoType)
        let attributeDict = try SecurityKeyPair.attributesDict(identifier: identifier,
                                                               cryptoType: cryptoType,
                                                               keySize: size,
                                                               hardwareSecured: false,
                                                               persistent: false)
        let privateKey = try SecurityKeyPair.generatePrivateKey(attributes: attributeDict)
        return try SecurityKeyPair.keyPair(privateKey: privateKey)
    }


    /// Generates public/private key pair in keychain. If persistent is passed as `true`
    /// this will persist the key pair on device and can be retrieved across app launches. Clear
    /// using the key pair using `func clearKeyPair(identifier: String, cryptoType: AsymmetricCryptoType)`
    /// when it is no longer required
    /// Please note that this method will first clear key pair generated with the passed identifier.
    ///
    /// - Parameters:
    ///   - size: keySize in bits to generate
    ///   - identifier: unique identifier that maps to the key pair
    ///   - cryptoType: asymmetric crypto. Currently RSA and ECC types are supported
    ///   - persistent: A boolean value indicating whether key pair needs to be persisted in keychain
    /// - Returns: generated key pair on success
    /// - Throws: error defined by `AWError.SDK.CryptoKit.AsymmetricCryptoPair`
    public static func generateKeyPair(size: UInt, identifier: String, cryptoType: AsymmetricCryptoType,
                                       persistent: Bool) throws -> SecurityKeyPair {

        _ = self.clearKeyPair(identifier: identifier,
                              cryptoType: cryptoType)
        let attributeDict = try SecurityKeyPair.attributesDict(identifier: identifier,
                                                               cryptoType: cryptoType,
                                                               keySize: size,
                                                               hardwareSecured: false,
                                                               persistent: persistent)
        let privateKey = try SecurityKeyPair.generatePrivateKey(attributes: attributeDict)
        return try SecurityKeyPair.keyPair(privateKey: privateKey)
    }

    /// Retrieves previously generated keypair stored on device. This method will throw error for
    /// for a non persistent key pair (persistent passed as false when generating keypair)
    ///
    /// - Parameters:
    ///   - identifier: unique identifier that maps to the key pair
    ///   - cryptoType: asymmetric crypto. Currently RSA and ECC types are supported
    /// - Returns: stored key pair on success
    /// - Throws: error defined by `AWError.SDK.CryptoKit.AsymmetricCryptoPair`
    public static func getKeyPair(identifier: String, cryptoType: AsymmetricCryptoType) throws -> SecurityKeyPair {
        let privateKeyTag = SecureKeyType.privateKey(cryptoType).applicationTag(identifier)

        var privateKeyGetQuery: [String: Any] = [kSecClass as String: kSecClassKey,
                                                 kSecAttrApplicationTag as String: privateKeyTag,
                                                 kSecAttrKeyType as String: cryptoType.keyTypeAttribute,
                                                 kSecReturnRef as String: true]
        if let keyPair = try? Self.getSecurityKeyPair(query: privateKeyGetQuery) {
            return keyPair
        } else if let applicationDataTag = privateKeyTag.data(using: .utf8) {
            privateKeyGetQuery[kSecAttrApplicationTag as String] = applicationDataTag
            return try Self.getSecurityKeyPair(query: privateKeyGetQuery)
        }
        throw RuntimeError("failedToRetrievePrivateKey")
    }

    private static func getSecurityKeyPair(query: [String: Any]) throws -> SecurityKeyPair {
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
                CFGetTypeID(item) == SecKeyGetTypeID() else {
            throw RuntimeError("AWError.SDK.CryptoKit.AsymmetricCryptoPair.failedToSign(error)")
           // throw AWError.SDK.CryptoKit.AsymmetricCryptoPair.failedToRetrievePrivateKey
        }
        let privateKey = item as! SecKey
        return try SecurityKeyPair.keyPair(privateKey: privateKey)
    }

    /// Clears previously generated key pair from device. Use it to clear any persistent key pair
    ///
    /// - Parameters:
    ///   - identifier: unique identifier that maps to the key pair
    ///   - cryptoType: asymmetric crypto. Currently RSA and ECC types are supported
    /// - Returns: key pair deletion iOS security status code (see SecBase.h)
    public static func clearKeyPair(identifier: String,
                                    cryptoType: AsymmetricCryptoType) -> OSStatus {

        let privateKeyTag = SecureKeyType.privateKey(cryptoType).applicationTag(identifier)
        var privateKeyDeletionQuery: [String: Any] = [kSecClass as String: kSecClassKey,
                                                      kSecAttrApplicationTag as String: privateKeyTag,
                                                      kSecAttrKeyType as String: cryptoType.keyTypeAttribute]

        let status = SecItemDelete(privateKeyDeletionQuery as CFDictionary)
        if status != errSecSuccess,
           let privateKeyDataTag = privateKeyTag.data(using: .utf8) {
            privateKeyDeletionQuery[kSecAttrApplicationTag as String] = privateKeyDataTag
            return SecItemDelete(privateKeyDeletionQuery as CFDictionary)
        }

        return status
    }

    /// Generates key pair with passed attributes and returns the private key
    ///
    /// - Parameter attributes: key pair attributes
    /// - Returns: private key on success
    /// - Throws: error defined by `AWError.SDK.CryptoKit.AsymmetricCryptoPair`
    private static func generatePrivateKey(attributes: [String: Any]) throws -> SecKey {
        #if targetEnvironment(simulator)
        if let value = attributes[String(kSecAttrTokenID)] as? String,
            value == String(kSecAttrTokenIDSecureEnclave) {
            let error = NSError(domain: NSOSStatusErrorDomain,
                                code: Int(errSecNotAvailable),
                                userInfo: [NSLocalizedDescriptionKey: "Key generation failed error \(errSecNotAvailable)"])
            throw RuntimeError("generationFailed: \(String(describing: error))")
        }
        #endif

        _ = SecItemDelete(attributes as CFDictionary)

        var errorRef: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &errorRef) else {
            let error = errorRef?.takeRetainedValue()
            throw RuntimeError("generationFailed: \(String(describing: error))")
        }

        return privateKey

    }

    /// Creates attributes dictionary based on the passed parameters
    ///
    /// - Parameters:
    ///   - identifier: unique identifier that maps to the key pair
    ///   - cryptoType: asymmetric crypto. Currently RSA and ECC types are supported
    ///   - keySize: keySize in bits to generate
    ///   - hardwareSecured: boolean that determines if key pair needs to be protected by iOS Secure Enclave
    ///   - persistent: boolean that determines if key pair needs to persist on device
    /// - Returns: attribute dictionary
    /// - Throws: error defined by `AWError.SDK.CryptoKit.AsymmetricCryptoPair`
    private static func attributesDict(identifier: String, cryptoType: AsymmetricCryptoType, keySize: UInt,
                                       hardwareSecured: Bool, persistent: Bool) throws -> [String: Any] {

        let privateKeyAttributes = try SecurityKeyPair.privateKeyAttributes(identifier: identifier,
                                                                            cryptoType: cryptoType,
                                                                            hardwareSecured: hardwareSecured,
                                                                            persistent: persistent)

        var attributes: [String: Any] = [
            kSecAttrKeyType as String:         cryptoType.keyTypeAttribute,
            kSecAttrKeySizeInBits as String:   keySize,
            kSecPrivateKeyAttrs as String:     privateKeyAttributes
        ]

        if hardwareSecured {
            attributes[kSecAttrTokenID as String] = kSecAttrTokenIDSecureEnclave
        }

        return attributes
    }

    /// Creates private key attributes dictionary
    ///
    /// - Parameters:
    ///   - identifier: unique identifier that maps to the key pair
    ///   - cryptoType: asymmetric crypto. Currently RSA and ECC types are supported
    ///   - hardwareSecured: boolean that determines if key pair needs to be protected by iOS Secure Enclave
    ///   - persistent: boolean that determines if key pair needs to persist on device
    /// - Returns: private key attributes dictionary
    /// - Throws: error defined by `AWError.SDK.CryptoKit.AsymmetricCryptoPair`
    private static func privateKeyAttributes(identifier: String,
                                             cryptoType: AsymmetricCryptoType,
                                             hardwareSecured: Bool,
                                             persistent: Bool) throws -> [String: Any] {

        //kSecAttrApplicationTag needs to be consistent if key was generated using iOS9 and is retrieved using iOS 10 API
        guard let applicationTag = SecureKeyType.privateKey(cryptoType).identifierData(identifier) else {
            throw RuntimeError("generationFailed: nil")
        }
        var privateKeyAttributes: [String: Any] =  [
            kSecAttrIsPermanent as String: persistent,
            kSecAttrApplicationTag as String: applicationTag]

        if hardwareSecured {
            var errorRef: Unmanaged<CFError>? = nil
            guard let accessControl = SecAccessControlCreateWithFlags(kCFAllocatorDefault,
                                                                      kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
                                                                      .privateKeyUsage,
                                                                      &errorRef) else {
                let error = errorRef?.takeRetainedValue()
                throw RuntimeError("failedToSign\(String(describing: error))")
            }
            privateKeyAttributes[kSecAttrAccessControl as String] = accessControl
        }

        return privateKeyAttributes
    }

    /// Generates public key from private key passed and returns key pair
    ///
    /// - Parameter privateKey: private key of the key pair
    /// - Returns: key pair
    /// - Throws: error defined by `AWError.SDK.CryptoKit.AsymmetricCryptoPair`
    private static func keyPair(privateKey: SecKey) throws -> SecurityKeyPair {

        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw RuntimeError("failedToRetrievePublicKey")
        }
        let secureKeyPair = SecurityKeyPair(publicKey: publicKey, privateKey: privateKey)
        return secureKeyPair
    }

}


internal struct SecKeyGenerator: SecKeyGenerationProtocol {}
internal struct SecKeySecurityProvider: SecKeySecurityProviderProtocol {

    internal let cryptoType: AsymmetricCryptoType
    internal let keyPair: SecurityKeyPair

    init(crypto: AsymmetricCryptoType, keyPair: SecurityKeyPair) {
        self.cryptoType = crypto
        self.keyPair = keyPair
    }
}
