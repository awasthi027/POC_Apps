//
//  AsymmetricKeyCryptor.swift
//  Crypto-Native
//
//  Created by Ashish Awasthi on 03/02/25.
//
import Foundation
import Security

internal protocol AsymmetricCryptorProtocol {
    var keyPair: SecurityKeyPair { get }
    var signingAlgorithm: SecKeyAlgorithm { get }
    var encryptionAlgorithm: SecKeyAlgorithm { get }
}

/// This class supports asymmetric cryptographic operations
/// for RSA and ECC crypto systems
public class AsymmetricKeyCryptor: AsymmetricCryptorProtocol {

    public let keyPair: SecurityKeyPair
    public let signingAlgorithm: SecKeyAlgorithm
    public let encryptionAlgorithm: SecKeyAlgorithm


    /// Creates the cryptor with signing and encryption algorithms.
    /// - Parameters:
    ///   - keyPair: public private key pair
    ///   - signingAlgo: signing algorithm to be used.
    ///   - encryptionAlgo: encryption algorithm to be used.
    public init(keyPair: SecurityKeyPair,
                 signingAlgo: SecKeyAlgorithm,
                 encryptionAlgo: SecKeyAlgorithm) {
        self.keyPair = keyPair
        self.signingAlgorithm = signingAlgo
        self.encryptionAlgorithm = encryptionAlgo
    }

    /// Creates the cryptor with passed private key.
    ///
    /// - Parameters:
    ///   - privateKey: private key part of the public private key pair
    ///   - signingAlgo: signing algorithm to be used.
    ///   - encryptionAlgo: ncryption algorithm to be used.
    public convenience init(privateKey: SecKey,
                            signingAlgo: SecKeyAlgorithm,
                             encryptionAlgo: SecKeyAlgorithm) {
        let pubKey = SecKeyCopyPublicKey(privateKey)
        self.init(keyPair: SecurityKeyPair(publicKey: pubKey, privateKey: privateKey),
                  signingAlgo: signingAlgo,
                  encryptionAlgo: encryptionAlgo)
    }


    /// Creates the cryptor based on passed cryptoType.
    /// For ECC, `ecdsaSignatureMessageX962SHA512` is used for signing and
    /// `eciesEncryptionCofactorX963SHA512AESGCM` for encryption
    /// For RSA, `rsaSignatureMessagePKCS1v15SHA512` is used for signing and
    /// `rsaEncryptionOAEPSHA512AESGCM` for encryption
    ///
    /// - Parameters:
    ///   - keyPair: public private key pair
    ///   - cryptoType: RSA or ECC
    public convenience init(keyPair: SecurityKeyPair,
                            cryptoType: AsymmetricCryptoType) {
        var signingAlgo: SecKeyAlgorithm
        var encryptionAlgo: SecKeyAlgorithm
        switch cryptoType {
        case .ecc:
            signingAlgo = .ecdsaSignatureMessageX962SHA512
            encryptionAlgo = .eciesEncryptionCofactorX963SHA512AESGCM

        case .rsa:
            signingAlgo = .rsaSignatureMessagePKCS1v15SHA512
            encryptionAlgo = .rsaEncryptionOAEPSHA512AESGCM
        }
        self.init(keyPair: keyPair,
                  signingAlgo: signingAlgo,
                  encryptionAlgo: encryptionAlgo)
    }


    /// Signs the passed data using the cryptor's signing algorithm.
    /// Please refer to apple documentation regarding any input data size constraints for the signing algorithm.
    /// This method will throw error if incompatible algorithm type is used for eg: RSA key pair with ECC signing algorithm
    ///
    /// - Parameter dataToSign: data that needs to be signed
    /// - Returns: Signature of the passed data
    /// - Throws: error defined by `AWError.SDK.CryptoKit.AsymmetricCryptoPair`
    public func sign(dataToSign: Data) throws -> Data {
        let privateKey = try self.retrievePrivateKey()
        return try AsymmetricKeyCryptor.sign(dataToSign: dataToSign,
                                          privateKey: privateKey,
                                          algorithm: self.signingAlgorithm)

    }

    /// Verifies the signature using cryptor's signing algorithm.
    /// This method will throw error if incompatible algorithm type is used for eg: RSA key pair with ECC signing algorithm
    ///
    /// - Parameters:
    ///   - signedData: the data that needs to be verified
    ///   - signature: signature of the data
    /// - Returns: `true` if verification succeeds
    /// - Throws: error defined by `AWError.SDK.CryptoKit.AsymmetricCryptoPair`
    public func verify(signedData: Data,
                       signature: Data) throws -> Bool {
        let publicKey = try self.retrievePublicKey()
        return try AsymmetricKeyCryptor.verify(signedData: signedData,
                                            signature: signature,
                                            publicKey: publicKey,
                                            algorithm: self.signingAlgorithm)
    }


    /// Encrypts the passed data using the cryptor's encryption algorithm.
    /// Please refer to apple documentation regarding any input data size constraints for the encryption algorithm.
    /// This method will throw error if incompatible algorithm type is used for eg: RSA key pair with ECC encrytion algorithm
    ///
    /// - Parameter plainText: data that needs to be encrypted
    /// - Returns: encrypted data
    /// - Throws: error defined by `AWError.SDK.CryptoKit.AsymmetricCryptoPair`
    public func encrypt(plainText: Data) throws -> Data {
        let publicKey = try self.retrievePublicKey()
        return try AsymmetricKeyCryptor.encrypt(plainText: plainText,
                                                publicKey: publicKey,
                                             algorithm: self.encryptionAlgorithm)

    }

    /// Encrypts the passed key using the cryptor's encryption algorithm.
    /// Please refer to apple documentation regarding any input key size constraints for the encryption algorithm.
    /// This method will throw error if incompatible algorithm type is used for eg: RSA key pair with ECC encrytion algorithm
    ///
    /// - Parameter rawKey: key to be encrypted
    /// - Returns: encrypted key data
    /// - Throws: error defined by `AWError.SDK.CryptoKit.AsymmetricCryptoPair`
    public func encryptKey(rawKey: Smaug) throws -> Data {
        let publicKey = try self.retrievePublicKey()
        return try AsymmetricKeyCryptor.encryptKey(rawKey: rawKey,
                                                   publicKey: publicKey,
                                                   algorithm: self.encryptionAlgorithm)

    }

    /// Decrypts the passed data using the cryptor's encryption algorithm.
    /// This method will throw error if incompatible algorithm type is used for eg: RSA key pair with ECC encrytion algorithm
    ///
    /// - Parameter encryptedData: encrypted data previously encrypted using the public key
    /// - Returns: decrypted data
    /// - Throws: error defined by `AWError.SDK.CryptoKit.AsymmetricCryptoPair`
    public func decrypt(encryptedData: Data) throws -> Data {
        let privateKey = try self.retrievePrivateKey()
        return try AsymmetricKeyCryptor.decrypt(encryptedData: encryptedData,
                                                privateKey: privateKey,
                                                algorithm: self.encryptionAlgorithm)

    }

    /// Decrypts the encrypted key data using the cryptor's encryption algorithm
    /// This method will throw error if incompatible algorithm type is used for eg: RSA key pair with ECC encrytion algorithm
    ///
    /// - Parameter encryptedKeyData: encrypted key data previously encrypted using the public key
    /// - Returns: raw key on successfull decryption
    /// - Throws: error defined by `AWError.SDK.CryptoKit.AsymmetricCryptoPair`
    public func decryptKey(encryptedKeyData: Data) throws -> Smaug {
        let privateKey = try self.retrievePrivateKey()
        return try AsymmetricKeyCryptor.decryptKey(encryptedKeyData: encryptedKeyData,
                                                   privateKey: privateKey,
                                                   algorithm: self.encryptionAlgorithm)
    }


    /// Helper to check and return public key if it is available
    ///
    /// - Returns: public key
    /// - Throws: error defined by `AWError.SDK.CryptoKit.AsymmetricCryptoPair`
    internal func retrievePublicKey() throws -> SecKey {
        guard let publicKey = self.keyPair.publicKey else {
           throw RuntimeError("AWError.SDK.CryptoKit.AsymmetricCryptoPair.publicKeyIsUnavailable")
        }

        return publicKey
    }


    /// Helper to check and return private key if it is available
    ///
    /// - Returns: private key
    /// - Throws: error defined by `AWError.SDK.CryptoKit.AsymmetricCryptoPair`
    internal func retrievePrivateKey() throws -> SecKey {
        guard let privateKey = self.keyPair.privateKey else {
            throw RuntimeError("AWError.SDK.CryptoKit.AsymmetricCryptoPair.privateKeyIsUnavailable")
        }
        return privateKey
    }


    /// Signs the message using the signing algorithm
    /// Please refer to apple documentation regarding any input data size constraints for the signing algorithm.
    /// This method will throw error if incompatible algorithm type is used for eg: RSA key pair with ECC signing algorithm
    /// - Parameters:
    ///   - dataToSign: data that needs to be signed
    ///   - privateKey: private key to sign the data
    ///   - algorithm: signing algorithm
    /// - Returns: signature of the data
    /// - Throws: error defined by `AWError.SDK.CryptoKit.AsymmetricCryptoPair`
    public static func sign(dataToSign: Data,
                            privateKey: SecKey,
                            algorithm: SecKeyAlgorithm) throws -> Data {

        guard SecKeyIsAlgorithmSupported(privateKey, .sign, algorithm) else {
           // throw AWError.SDK.CryptoKit.AsymmetricCryptoPair.algorithmNotSupported
            return Data()
        }

        var errorRef: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(privateKey,
                                                    algorithm,
                                                    dataToSign as CFData,
                                                    &errorRef) as Data?
            else {
                let error = errorRef?.takeRetainedValue()
            throw RuntimeError("failedToSign:\(String(describing: error))")
                //log(error: "error signing: \(String(describing: error))")
              //  throw AWError.SDK.CryptoKit.AsymmetricCryptoPair.failedToSign(error)
        }

        return signature as Data
    }

    /// Verifies the signature using the signing algorithm
    /// This method will throw error if incompatible algorithm type is used for eg: RSA key pair with ECC signing algorithm
    ///
    /// - Parameters:
    ///   - signedData: the data that needs to be verified
    ///   - signature: signature of the data
    ///   - publicKey: public key to verify the signature
    ///   - algorithm: signing algorithm
    /// - Returns: `true` if verification succeeds
    /// - Throws: error defined by `AWError.SDK.CryptoKit.AsymmetricCryptoPair`
    public static func verify(signedData: Data,
                              signature: Data,
                              publicKey: SecKey,
                              algorithm: SecKeyAlgorithm) throws -> Bool {

        guard SecKeyIsAlgorithmSupported(publicKey, .verify, algorithm) else {
           // throw AWError.SDK.CryptoKit.AsymmetricCryptoPair.algorithmNotSupported
            return true
        }

        guard signedData.isNotEmpty else {
           // log(error: "Can not verify signature with empty signed data")
            return false
        }

        var errorRef: Unmanaged<CFError>?
        guard SecKeyVerifySignature(publicKey,
                                    algorithm,
                                    signedData as CFData,
                                    signature as CFData,
                                    &errorRef)
            else {
               // log(error: "error verifying: \(String(describing: errorRef?.takeRetainedValue() as Error?))")
                return false
        }

        return true

    }

    /// Encrypts the passed data using the cryptor's encryption algorithm.
    /// Please refer to apple documentation regarding any input data size constraints for the encryption algorithm.
    /// This method will throw error if incompatible algorithm type is used for eg: RSA key pair with ECC encryption algorithm
    /// - Parameters:
    ///   - plainText: data that needs to be encrypted
    ///   - publicKey: public key to encrypt the data
    ///   - algorithm: encryption algorithm
    /// - Returns: encrypted data
    /// - Throws: error defined by `AWError.SDK.CryptoKit.AsymmetricCryptoPair`
    public static func encrypt(plainText: Data,
                               publicKey: SecKey,
                               algorithm: SecKeyAlgorithm) throws -> Data {
       return try AsymmetricKeyCryptor.encrypt(value: plainText,
                                               publicKey: publicKey,
                                               algorithm: algorithm)
    }

    /// Encrypts the passed key using the cryptor's encryption algorithm.
    /// Please refer to apple documentation regarding any input data size (for keys) constraints for the encryption algorithm.
    /// This method will throw error if incompatible algorithm type is used for eg: RSA key pair with ECC encryption algorithm
    /// - Parameters:
    ///   - rawKey: rawKey to be encrypted
    ///   - publicKey: public key to encrypt the data
    ///   - algorithm: encryption algorithm
    /// - Returns: encrypted key data
    /// - Throws: error defined by `AWError.SDK.CryptoKit.AsymmetricCryptoPair`
    public static func encryptKey(rawKey: Smaug,
                                  publicKey: SecKey,
                                  algorithm: SecKeyAlgorithm) throws -> Data {
       return try AsymmetricKeyCryptor.encrypt(value: rawKey,
                                               publicKey: publicKey,
                                               algorithm: algorithm)
    }

    /// we use generics here to make sure secure smaug object is not passed as data to this method
    internal static func encrypt<T>(value: T,
                                    publicKey: SecKey,
                                    algorithm: SecKeyAlgorithm) throws -> Data {
        guard SecKeyIsAlgorithmSupported(publicKey, .encrypt,
                                         algorithm) else {
           // throw AWError.SDK.CryptoKit.AsymmetricCryptoPair.algorithmNotSupported
            return Data()
        }

        var dataToEncrypt: Data = Data()
        switch value {
        case let data as Data:
            dataToEncrypt = data
        case let smaug as Smaug:
            dataToEncrypt = smaug.securedData
        default:
            throw RuntimeError("AsymmetricCryptoPair")
        }

        var errorRef: Unmanaged<CFError>?
        guard let encryptedData = SecKeyCreateEncryptedData(publicKey, algorithm, dataToEncrypt as CFData, &errorRef) else {
            let error = errorRef?.takeRetainedValue()
            throw RuntimeError("encryptionFailed: \(error)")
        }

        return encryptedData as Data
    }


    /// Decrypyts the passed data using the encryption algorithm.
    /// This method will throw error if incompatible algorithm type is used for eg: RSA key pair with ECC encryption algorithm
    ///
    /// - Parameters:
    ///   - encryptedData: data that was encrypted using the encryption algorithm.
    ///   - privateKey: private key to be used for decryption
    ///   - algorithm: encryption algorithm.
    /// - Returns: decrypted data
    /// - Throws: error defined by `AWError.SDK.CryptoKit.AsymmetricCryptoPair`
    public static func decrypt(encryptedData: Data,
                               privateKey: SecKey,
                               algorithm: SecKeyAlgorithm) throws -> Data {
        return try AsymmetricKeyCryptor.decrypt(encrypted: encryptedData,
                                                privateKey: privateKey,
                                                algorithm: algorithm)
    }

    /// Decrypyts the encrypted key data using the encryption algorithm.
    /// This method will throw error if incompatible algorithm type is used for eg: RSA key pair with ECC encryption algorithm
    ///
    /// - Parameters:
    ///   - encryptedKeyData: encrypted key data previously encrypted using the public key and the encryption algorithm
    ///   - privateKey: private key to be used for decryption
    ///   - algorithm: encryption algorithm
    /// - Returns: raw key on successful decryption
    /// - Throws: error defined by `AWError.SDK.CryptoKit.AsymmetricCryptoPair`
    public static func decryptKey(encryptedKeyData: Data,
                                  privateKey: SecKey,
                                  algorithm: SecKeyAlgorithm) throws -> Smaug {
        return try AsymmetricKeyCryptor.decrypt(encrypted: encryptedKeyData,
                                                privateKey: privateKey,
                                                algorithm: algorithm)
    }

    ///we use generics here to make sure secure smaug object is not passed as data to this method
    internal static func decrypt<T>(encrypted: Data,
                                    privateKey: SecKey,
                                    algorithm: SecKeyAlgorithm) throws -> T {
        guard SecKeyIsAlgorithmSupported(privateKey, .decrypt, algorithm) else {
            //throw AWError.SDK.CryptoKit.AsymmetricCryptoPair.algorithmNotSupported
            return Data() as! T
        }

        var errorRef: Unmanaged<CFError>?
        guard var decryptedData = SecKeyCreateDecryptedData(privateKey, algorithm,
                                                            encrypted as CFData, &errorRef) as Data? else {
            let error = errorRef?.takeRetainedValue()
            //log(error: "error decrypting: \(String(describing: error))")
           // throw AWError.SDK.CryptoKit.AsymmetricCryptoPair.decryptionFailed(error)
            throw RuntimeError("AWError.SDK.CryptoKit.AsymmetricCryptoPair.failedToSign:\(String(describing: error))")
        }
        let decrypted: T?

        switch T.self {
        case is Data.Type:
            decrypted = decryptedData as? T

        case is Smaug.Type:
            guard let keySmaug = Smaug(data: &decryptedData) else {
              //  throw AWError.SDK.CryptoKit.AsymmetricCryptoPair.failedToConvertToSmaug
                return Data() as! T
            }
            decrypted = keySmaug as? T

        default:
            decrypted = nil
        }

        guard let value = decrypted else {
            //throw AWError.SDK.CryptoKit.AsymmetricCryptoPair.invalidParameterType
            return Data() as! T
        }

        return value
    }
}


internal enum SecureKeyType {
    case publicKey(AsymmetricCryptoType)
    case privateKey(AsymmetricCryptoType)

    internal var tag: String {
        switch self {
        case .privateKey(let cryptoType):
            return "\(cryptoType.identifier).private.tag"

        case .publicKey(let cryptoType):
            return "\(cryptoType.identifier).public.tag"
        }
    }

    internal var queryAttribute: CFString {
        switch self {
        case .privateKey(let cryptoType):
            return cryptoType.keyTypeAttribute

        case .publicKey(let cryptoType):
            return cryptoType.keyTypeAttribute
        }
    }

    internal func applicationTag(_ identifier: String?) -> String {
        if let id = identifier {
            return (id + self.tag)
        }

        return self.tag
    }

    internal func identifierData(_ identifier: String?) -> Data? {
        if let id = identifier {
            return (id + self.tag).data(using: .utf8)
        }

        return self.tag.data(using: .utf8)
    }


    internal func attributes(_ identifier: String?) -> [String: NSObject] {
        var map: [String: NSObject] =  [
            String(kSecClass): kSecClassKey as NSString,
            String(kSecAttrKeyType): self.queryAttribute as NSString
        ]

#if os(iOS)
        if let data = self.identifierData(identifier) {
            map[String(kSecAttrApplicationTag)] = data as NSData
        }
#elseif os(OSX)
        if let data = identifier?.data(using: .utf8) {
            map[String(kSecAttrApplicationTag)] = data as NSData
        }
#endif

        switch self {
        case .privateKey:
            map[String(kSecAttrKeyClass)] = kSecAttrKeyClassPrivate

        case .publicKey:
            map[String(kSecAttrKeyClass)] = kSecAttrKeyClassPublic
#if os(iOS)
            map[String(kSecAttrAccessible)] = kSecAttrAccessibleWhenUnlocked
#endif
        }

        return map
    }

    internal func dataConversionAttributes(_ identifier: String?) -> [String: NSObject] {
        var attributes = self.attributes(identifier)
        attributes[String(kSecReturnData)] = true as NSNumber
        return attributes
    }

    //this API will need keyType
    internal func referenceConversionAttributes(_ identifier: String?) -> [String: NSObject] {
        var attributes = self.attributes(identifier)
        attributes[String(kSecReturnRef)] = true as NSNumber
        return attributes
    }
}
