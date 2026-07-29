//
//  NURLSessionView.swift
//  CBAAuthentication
//
//  Created by Ashish Awasthi on 22/07/26.
//

import SwiftUI
struct SessionView: View {
   @StateObject var cbaClient: CBAClient = CBAClient()
    private let cbaURL = URL(string: "https://client.badssl.com/")!

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Welcome to CBA Authentication")
                .font(.headline)
            Button("Test CBA Challenge") {
                cbaClient.testCBA()
            }
            Text(self.cbaClient.result)
            Spacer()
        }
        .onAppear {

        }
    }
}

import Foundation
internal import Combine

class CBAClient: NSObject,
                ObservableObject,
                 URLSessionDelegate {
    @Published var result: String = ""
    func testCBA() {
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config,
                                 delegate: self, delegateQueue: nil)

        let task = session.dataTask(with: URL(string: "https://client.badssl.com/")!) { data, response, error in
            if let http = response as? HTTPURLResponse {
                print("Status: \(http.statusCode)")  // 200 = cert accepted
            }
            if let data = data, let body = String(data: data, encoding: .utf8) {
                print(body)
                self.result = body
            }
        }
        task.resume()
    }

    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let method = challenge.protectionSpace.authenticationMethod
        if method == NSURLAuthenticationMethodClientCertificate,
           let identity = KeychainCertificateManager.shared.bundleCertificateSecIdentity() {
            let credential = URLCredential(identity: identity,
                                           certificates: nil,
                                           persistence: .forSession)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

