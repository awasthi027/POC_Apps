//
//  WKWebViewModel.swift
//  CBAAuthentication
//
//  Created by Ashish Awasthi on 29/07/26.
//
// "https://isdkweb03.ssdevrd.com:8443/ia"

import Foundation

class CBAWKWebViewModel {
    let cbaURL: URL
    let secIdentity: SecIdentity?
    init(cbaURL: URL,
         secIdentity: SecIdentity?) {
        self.cbaURL = cbaURL
        self.secIdentity = secIdentity
    }
}
