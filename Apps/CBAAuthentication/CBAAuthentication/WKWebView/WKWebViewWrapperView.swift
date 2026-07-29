//
//  WKWebViewWrapperView.swift
//  CBAAuthentication
//
//  Created by Ashish Awasthi on 29/07/26.
//

import Foundation
import SwiftUI
import WebKit
import Security

struct WKWebViewWrapperView: UIViewRepresentable {
    let url: URL
    var secIdentity: SecIdentity?

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url, secIdentity: secIdentity)
    }
}

final class Coordinator: NSObject, WKNavigationDelegate {
    private let url: URL
    var secIdentity: SecIdentity?
    weak var webView: WKWebView?

    init(url: URL, secIdentity: SecIdentity?) {
        self.url = url
        self.secIdentity = secIdentity
    }

    func webView(_ webView: WKWebView,
                 didReceive challenge: URLAuthenticationChallenge,
                 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        if self.secIdentity == nil {
            if let (identity, tokenID) = CTKManager.shared.selectTokenIdentity(for: challenge) {
                self.secIdentity = identity
                print("WKWebViewWrapperView: using CTK identity from token '\(tokenID)'")
            }
        }
        print("WKWebViewWrapperView: using CTK identity from token ")
        // Let CryptoTokenKit provide the identity — from THIS or any other app's token.
        if let identity = secIdentity {
            //It hands back URLCredential(identity:). The private-key signing is delegated to whichever app's persistent-token extension owns that identity — this app never touches the key. If that token is biometric, its owning extension shows the Face ID/passcode prompt during the handshake.
            // Use `.forSession` so WebKit caches the accepted client credential for the
            // session. With `.none` the credential is not cached, so every TLS connection
            // (document, sub-resources, renegotiation) re-issues the client-certificate
            // challenge, causing CryptoTokenKit to re-instantiate the token (tokenFor) and
            // prompt for Face ID/PIN repeatedly.
            let credential = URLCredential(identity: identity,
                                           certificates: nil,
                                           persistence: .forSession)
            completionHandler(.useCredential, credential)
        } else {
            print("WKWebViewWrapperView: no matching CTK identity — cancelling challenge")
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
