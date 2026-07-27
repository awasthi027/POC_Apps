//
//  CBAWebView.swift
//  CBAAuthentication
//
//  Created by Ashish Awasthi on 22/07/26.
//

import SwiftUI
import WebKit

/// A SwiftUI wrapper around `WKWebView` that loads a URL and handles
/// client-certificate (CBA) authentication challenges during the TLS handshake.
struct CBAWebView: UIViewRepresentable {

    /// The URL to load in the web view.
    let url: URL
    var certificateName: String?
    var certificatePassword: String?

    func makeCoordinator() -> Coordinator {
        return Coordinator(certificateName: certificateName,
                           certificatePassword: certificatePassword)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Only load once to avoid reloading on every SwiftUI update.
        if webView.url == nil {
            webView.load(URLRequest(url: url))
        }
    }

    /// Handles WKWebView navigation and the client-certificate authentication challenge.
    final class Coordinator: NSObject, WKNavigationDelegate {

        var certificateName: String?
        var certificatePassword: String?

        private var identity: SecIdentity?

        init(certificateName: String?,
                      certificatePassword: String?) {
            super.init()
            self.certificateName = certificateName
            self.certificatePassword = certificatePassword
            loadIdentity()
        }

        /// Loads the client identity strictly from the app keychain.
        private func loadIdentity() {
            guard let certificateName = self.certificateName,
              let certificatePassword = self.certificatePassword else {
                self.identity = KeychainCertificateManager.shared.loadIdentity()
                if identity == nil {
                    print("CBAWebView: no client identity available in Keychain")
                }
                return
            }
            self.loadIdentity(p12Path: certificateName,
                              password: certificatePassword)
        }

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

        // MARK: - WKNavigationDelegate

        /// Called when the server issues an authentication challenge (including client-cert / CBA).
        func webView(_ webView: WKWebView,
                     didReceive challenge: URLAuthenticationChallenge,
                     completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

            let method = challenge.protectionSpace.authenticationMethod

            if method == NSURLAuthenticationMethodClientCertificate {
                // Refresh from keychain so newly imported identities can be used without recreating the app state.
                self.identity = KeychainCertificateManager.shared.loadIdentity()

                if let identity {
                    let credential = URLCredential(identity: identity,
                                                   certificates: nil,
                                                   persistence: .forSession)
                    completionHandler(.useCredential, credential)
                } else {
                    print("CBAWebView: client-cert challenge received, but no identity in app keychain")
                    completionHandler(.rejectProtectionSpace, nil)
                }
            } else {
                // Fall back to the default handling for server trust, basic auth, etc.
                completionHandler(.performDefaultHandling, nil)
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            print("CBAWebView: started loading \(webView.url?.absoluteString ?? "")")
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("CBAWebView: finished loading \(webView.url?.absoluteString ?? "")")
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("CBAWebView: navigation failed - \(error.localizedDescription)")
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("CBAWebView: provisional navigation failed - \(error.localizedDescription)")
        }
    }
}

