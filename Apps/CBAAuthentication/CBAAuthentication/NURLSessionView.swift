//
//  NURLSessionView.swift
//  CBAAuthentication
//
//  Created by Ashish Awasthi on 22/07/26.
//

import SwiftUI


struct NURLSessionView: View {
    let cbaClient: CBAClient = CBAClient()
    private let cbaURL = URL(string: "https://client.badssl.com/")!

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Welcome to CBA Authentication")
                .font(.headline)
            Button("Test CBA Challenge") {
                cbaClient.loadIdentity(p12Path: "badssl.com-client",
                                          password: "badssl.com")
                cbaClient.testCBA()
            }
            Spacer()
        }
        .onAppear {

        }
    }
}
