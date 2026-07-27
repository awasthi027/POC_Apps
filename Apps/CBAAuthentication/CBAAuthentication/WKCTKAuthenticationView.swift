//
//  WKCTKAuthenticationView.swift
//  CBAAuthentication
//
//  Created by Ashish Awasthi on 23/07/26.
//

import SwiftUI
import WebKit

struct WKCTKAuthenticationView: View {
    private let cbaURL = URL(string: "https://client.badssl.com/")!

    var body: some View {
        VStack {
            WKCTKWrapperView(url: cbaURL)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        }
      
    }

}

//
//  WKCTKWrapperView.swift
//  CBAAuthentication
//
//  A WKWebView wrapper that answers a TLS client-certificate (mTLS) challenge using an
//  identity provided by ANY CryptoTokenKit persistent token — not just our own.
//
//  This is a generic CTK *consumer*: it does not hardcode a token ID. It enumerates the
//  token-backed identities the system exposes (the `com.apple.token` access group), which
//  may have been installed by THIS app or by a completely different app (e.g. a PIV-D
//  manager or a smart-card provider). It selects the identity whose issuer matches the
//  server's accepted CAs and hands it back.
//
//  The private-key signature is performed by whichever app's persistent-token extension owns
//  the chosen identity — this app never sees the private key. If that token requires user
//  interaction, the owning extension prompts (Face ID / passcode) during the handshake.
//
//  Requires: the app entitled to read the token access group (`com.apple.token`), and at
//  least one client certificate installed in CTK by some app.
import SwiftUI
import WebKit
import Security

struct WKCTKWrapperView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKNavigationDelegate {

        func webView(_ webView: WKWebView,
                     didReceive challenge: URLAuthenticationChallenge,
                     completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

            guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate else {
                completionHandler(.performDefaultHandling, nil)
                return
            }

            // Let CryptoTokenKit provide the identity — from THIS or any other app's token.
            if let (identity, tokenID) = CTKManager.shared.selectTokenIdentity(for: challenge) {
                print("WKCTKWrapperView: using CTK identity from token '\(tokenID)'")
                //It hands back URLCredential(identity:). The private-key signing is delegated to whichever app's persistent-token extension owns that identity — this app never touches the key. If that token is biometric, its owning extension shows the Face ID/passcode prompt during the handshake.
                let credential = URLCredential(identity: identity,
                                               certificates: nil,
                                               persistence: .forSession)
                completionHandler(.useCredential, credential)
            } else {
                print("WKCTKWrapperView: no matching CTK identity — cancelling challenge")
                completionHandler(.cancelAuthenticationChallenge, nil)
            }
        }
    }
}
