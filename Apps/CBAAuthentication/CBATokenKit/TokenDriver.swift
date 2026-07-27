//
//  TokenDriver.swift
//  CBATokenKit
//
//  Created by Ashish Awasthi on 23/07/26.
//

import CryptoTokenKit

class TokenDriver: TKTokenDriver, TKTokenDriverDelegate {

    func tokenDriver(_ driver: TKTokenDriver, tokenFor configuration: TKToken.Configuration) throws -> TKToken {
        return Token(tokenDriver: self,
                     instanceID: configuration.instanceID,
                     configurationData: configuration.configurationData)
    }

}
