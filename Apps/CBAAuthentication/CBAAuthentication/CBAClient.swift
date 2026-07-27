//
//  CBAClient.swift
//  CBAAuthentication
//
//  Created by Ashish Awasthi on 22/07/26.
//

import Foundation

class CBAClient: NSObject, URLSessionDelegate {
    private var identity: SecIdentity?

    func loadIdentity(p12Path: String, password: String) {
        let url = Bundle.main.url(forResource: p12Path, withExtension: "p12")!
        let p12Data = try! Data(contentsOf: url)
        let options = [kSecImportExportPassphrase as String: password]
        var items: CFArray?
        let status = SecPKCS12Import(p12Data as CFData, options as CFDictionary, &items)

        guard status == errSecSuccess,
              let itemArray = items as? [[String: Any]],
              let firstItem = itemArray.first,
              let identity = firstItem[kSecImportItemIdentity as String] else {
            print("Failed to import p12")
            return
        }
        self.identity = (identity as! SecIdentity)
    }

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
            }
        }
        task.resume()
    }

    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let method = challenge.protectionSpace.authenticationMethod
        if method == NSURLAuthenticationMethodClientCertificate,
           let identity = identity {
            let credential = URLCredential(identity: identity,
                                           certificates: nil,
                                           persistence: .forSession)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
