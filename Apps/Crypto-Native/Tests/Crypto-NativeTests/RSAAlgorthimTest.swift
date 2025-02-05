import Testing
@testable import Crypto_Native
import Foundation


@Test func testBlankData()  async throws {
    let pairGenerator = SecKeyGenerator()
    let id = "testEncryption"
    let securityProvider = try! pairGenerator.rsaKeyPair(identifier: id)
    do {
        let blankData = Data()
        let decryptData = try securityProvider.decrypt(data: blankData)
        #expect(decryptData == nil, "Expecting Nil data")
    } catch let error {
        #expect(error != nil,"error should be thrown in case of empty data")
    }
}

@Test func testUnEncryptedData()  async throws {
    let pairGenerator = SecKeyGenerator()
    let id = "testEncryption"
    let securityProvider = try! pairGenerator.rsaKeyPair(identifier: id)
    do {
        let unEncryptedData = Data.randomData(count: 10)
        let decryptData = try securityProvider.decrypt(data: unEncryptedData)
        #expect(decryptData == nil, "Expecting Nil data")
    } catch let error {
        #expect(error != nil,"error should be thrown in case of empty data")
    }
}
/*
 RSA Block Size: RSA encryption operates on blocks of data of a specific size. This size is determined by the RSA key length. Common key sizes are 2048 bits, 3072 bits, and 4096 bits. A 2048-bit key, for example, can encrypt a plaintext block of 256 bytes (2048 bits / 8 bits per byte).
 Padding: Because your data might not perfectly align with the RSA block size, padding is used. Padding adds extra bytes to the data to fill the block. Common padding schemes include PKCS#1 v1.5 padding and PKCS#1 OAEP padding

 keySize - 11 For PKCS1v1.5 padding is 11

 Just example:

 Common key sizes are 2048 bits, 3072 bits, and 4096 bits

 If key size 2048 encrypted data size = 2048 bits/ 8 bit = 256 and maximum unencrypted data can encrypted with key is 256 - 11 = 245

 If key size 3072 encrypted data size = 3072 bits/ 8 bit =384 and maximum unencrypted data can encrypted with key is 384 - 11 = 381

 If key size 4096 encrypted data size = 4096 bits/ 8 bit =512 and maximum unencrypted data can encrypted with key is 512 - 11 = 501
 */

@Test func testUnEncryptedDataMore20Bytes() async throws {

    let pairGenerator = SecKeyGenerator()
    let id = "testEncryption"
    let securityProvider = try! pairGenerator.rsaKeyPair(identifier: id)
    do {
        let unEncryptedData = Data.randomData(count: 22) // Random data that is NOT encrypted
        let decryptData = try securityProvider.decrypt(data: unEncryptedData)
        #expect(decryptData == nil, "Expecting Nil data")
    } catch let error {
        #expect(error != nil,"error should be thrown in case of empty data")
    }
}

@Test func testEncryptAndDecrypt() async throws {
    let pairGenerator = SecKeyGenerator()
    let id = "testEncryption"
    let securityProvider = try! pairGenerator.rsaKeyPair(identifier: id)
    do {
        let testingMessage = "Encrypt message annd test"
        guard let testData = testingMessage.data(using: .utf8) else { return }
        var goodData = testData
        let smaug = Smaug(data: &goodData)!
        let enyData = try securityProvider.encrypt(key: smaug)
        let decryptData = try securityProvider.decrypt(data: enyData)
        let toString = decryptData.securedData.toString
        #expect(toString == testingMessage)
    } catch let error {
        #expect(error != nil,"error should be thrown in case of empty data")
    }
}

@Test func testEncryptEmptyData()  async throws {
    let pairGenerator = SecKeyGenerator()
    let id = "testEncryption"
    let securityProvider = try! pairGenerator.rsaKeyPair(identifier: id)
    do {
        let testingMessage = ""
        guard let testData = testingMessage.data(using: .utf8) else { return }
        var goodData = testData
        guard let smaug = Smaug(data: &goodData) else { return }
        let enyData = try securityProvider.encrypt(key: smaug)
        #expect(enyData == nil)
    } catch let error {
        #expect(error == nil,"error should be thrown in case of empty data")
    }
}

@Test func maximumDataEncryptWithKeySize_2048() async throws {

    let pairGenerator = SecKeyGenerator()
    let id = "testEncryption"
    let securityProvider = try! pairGenerator.rsaKeyPair(identifier: id,
                                                         keySize: 2048)
    do {
        var goodData = Data.randomData(count: 245)
        guard let smaug = Smaug(data: &goodData) else { return }
        let enyData = try securityProvider.encrypt(key: smaug)
        #expect(enyData.count == 256)
    } catch let error {
        #expect(error == nil,"error should be thrown in case of empty data")
    }
}

@Test func moreThanMaximumEncryptWithKeySize_2048() async throws {
    let pairGenerator = SecKeyGenerator()
    let id = "testEncryption"
    let securityProvider = try! pairGenerator.rsaKeyPair(identifier: id,
                                                         keySize: 2048)
    do {
        var goodData = Data.randomData(count: 246)
        guard let smaug = Smaug(data: &goodData) else { return }
        let _ = try securityProvider.encrypt(key: smaug)
    } catch let error {
        #expect(error != nil,"error should be thrown in case of empty data")
    }
}

@Test func maximumDataEncryptWithKeySize_3072() async throws {

    let pairGenerator = SecKeyGenerator()
    let id = "testEncryption"
    let securityProvider = try! pairGenerator.rsaKeyPair(identifier: id,
                                                         keySize: 3072)
    do {
        var goodData = Data.randomData(count: 373)
        guard let smaug = Smaug(data: &goodData) else { return }
        let enyData = try securityProvider.encrypt(key: smaug)
        #expect(enyData.count == 384)
    } catch let error {
        #expect(error == nil,"error should be thrown in case of empty data")
    }
}

@Test func maximumDataEncryptWithKeySize_512()  async throws {
    let pairGenerator = SecKeyGenerator()
    let id = "testEncryption"
    let securityProvider = try! pairGenerator.rsaKeyPair(identifier: id,
                                                         keySize: 4096)
    do {
        var goodData = Data.randomData(count: 501)
        guard let smaug = Smaug(data: &goodData) else { return }
        let enyData = try securityProvider.encrypt(key: smaug)
        #expect(enyData.count == 512)
    } catch let error {
        #expect(error == nil,"error should be thrown in case of empty data")
    }
}
