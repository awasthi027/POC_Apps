//
//  SSLPinningTestingTests.swift
//  SSLPinningTestingTests
//
//  Created by Ashish Awasthi on 17/06/26.
//

import Foundation
import Testing
@testable import SSLPinningTesting

struct SSLPinningTestingTests {

    @Test func decodesSecurePingResponse() throws {
        let json = #"{"message":"pong over a pinned TLS connection","secure":true}"#

        let response = try JSONDecoder().decode(SecurePingResponse.self, from: Data(json.utf8))

        #expect(response.message == "pong over a pinned TLS connection")
        #expect(response.secure)
    }

    @Test func decodesVerifyResponseForRejectedPin() throws {
        let json = #"{"expectedPin":"sha256/6dyaikcY3JVr3G5qTKYXKmbBEjHi2cd1R7eLwl97V94=","pinUsed":"sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=","pinningPassed":false,"error":"CertificateException: Certificate pinning failure."}"#

        let response = try JSONDecoder().decode(VerifyResponse.self, from: Data(json.utf8))

        #expect(response.expectedPin == "sha256/6dyaikcY3JVr3G5qTKYXKmbBEjHi2cd1R7eLwl97V94=")
        #expect(response.pinUsed == "sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=")
        #expect(response.pinningPassed == false)
        #expect(response.error == "CertificateException: Certificate pinning failure.")
        #expect(response.statusCode == nil)
    }

}
