//
//  EcdhInitRequest.swift
//  SecurityTestApp
//
//  Created by Ashish Awasthi on 13/06/26.
//

import Foundation

struct EcdhInitRequest: Codable {
    let deviceId: String
    let deviceType: String
    let clientPublicKey: String
    let clientNonce: String
}

