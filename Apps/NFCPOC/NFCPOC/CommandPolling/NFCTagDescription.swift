//
//  NFCTagDescription.swift
//  NFCPOC
//
//  Created by Ashish Awasthi on 20/10/23.
//

import Foundation
import CoreNFC

struct NFCTagDescription {
    var identifier: Data = Data()
    var historicalBytes: Data = Data()

    init(tag: NFCTag?) {
        let tagiIsNil = tag == nil
        debugPrint("Command:- tagiIsNil: \(tagiIsNil)")
        guard let tag = tag else {
            return
        }
        if case .iso7816(let nfcISO7816Tag) = tag {
            debugPrint("Command:-  nfcISO7816Tag.identifier: \( nfcISO7816Tag.identifier)")
            self.identifier = nfcISO7816Tag.identifier
            self.historicalBytes = nfcISO7816Tag.historicalBytes ?? Data()
        }
    }
}
