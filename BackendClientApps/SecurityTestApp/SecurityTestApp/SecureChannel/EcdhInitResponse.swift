//
//  EcdhInitResponse.swift
//  SecurityTestApp
//
//  Created by Ashish Awasthi on 13/06/26.
//

struct EcdhInitResponse: Codable {
    let sessionId: String
    let deviceId: String
    let deviceType: String
    let serverPublicKey: String
    let serverNonce: String
    let serverProof: String
    let status: String
}

struct EcdhConfirmRequest: Codable {
    let sessionId: String
    let clientProof: String
}

struct EcdhConfirmResponse: Codable {
    let sessionId: String
    let status: String
    let hmacKey: String?
}
