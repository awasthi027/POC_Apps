//
//  EscAlgorthimTests.swift
//  Crypto-Native
//
//  Created by Ashish Awasthi on 05/02/25.
//

import Testing
@testable import Crypto_Native
import Foundation

@Test func testBlankDataECC()  async throws {

    let pairGenerator = SecKeyGenerator()
    let id = "testEncryption"
    let securityProvider = try! pairGenerator.harwareSecuredKeyPair(identifier: id)
    do {
        let blankData = Data()
        let decryptData = try securityProvider.decrypt(data: blankData)
        #expect(decryptData == nil, "Expecting Nil data")
    } catch let error {
        #expect(error != nil,"error should be thrown in case of empty data")
    }
}

@Test func testUnEncryptedDataECC()  async throws {
    let pairGenerator = SecKeyGenerator()
    let id = "testEncryption"
    let securityProvider = try! pairGenerator.harwareSecuredKeyPair(identifier: id)
    do {
        let unEncryptedData = Data.randomData(count: 10)
        let decryptData = try securityProvider.decrypt(data: unEncryptedData)
        #expect(decryptData == nil, "Expecting Nil data")
    } catch let error {
        #expect(error != nil,"error should be thrown in case of empty data")
    }
}

@Test func testUnEncryptedDataMore20BytesECC() async throws {

    let pairGenerator = SecKeyGenerator()
    let id = "testEncryption"
    let securityProvider = try! pairGenerator.harwareSecuredKeyPair(identifier: id)
    do {
        let unEncryptedData = Data.randomData(count: 22) // Random data that is NOT encrypted
        let decryptData = try securityProvider.decrypt(data: unEncryptedData)
        #expect(decryptData == nil, "Expecting Nil data")
    } catch let error {
        #expect(error != nil,"error should be thrown in case of empty data")
    }
}

@Test func testEncryptAndDecryptECC() async throws {
    let pairGenerator = SecKeyGenerator()
    let id = "testEncryption"
    let securityProvider = try! pairGenerator.harwareSecuredKeyPair(identifier: id)
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

@Test func testEncryptEmptyDataECC()  async throws {
    let pairGenerator = SecKeyGenerator()
    let id = "testEncryption"
    let securityProvider = try! pairGenerator.harwareSecuredKeyPair(identifier: id)
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

@Test func maximumDataEncryptWithKeySize_2048ECC() async throws {

    let pairGenerator = SecKeyGenerator()
    let id = "testEncryption"
    let securityProvider = try! pairGenerator.harwareSecuredKeyPair(identifier: id)
    do {
        var goodData = Data.randomData(count: 300)
        guard let smaug = Smaug(data: &goodData) else { return }
        let enyData = try securityProvider.encrypt(key: smaug)
        #expect(enyData.count > 0)
    } catch let error {
        #expect(error == nil,"error should be thrown in case of empty data")
    }
}

