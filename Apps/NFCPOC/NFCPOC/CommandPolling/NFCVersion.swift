//
//  NFCVersion.swift
//  NFCPOC
//
//  Created by Ashish Awasthi on 21/10/23.
//

import Foundation

struct NFCVersion {
    var  major: UInt8
    var  minor: UInt8
    var  micro: UInt8

    init(major: UInt8,
         minor: UInt8,
         micro: UInt8) {
        self.major = major
        self.minor = minor
        self.micro = micro
    }
}
