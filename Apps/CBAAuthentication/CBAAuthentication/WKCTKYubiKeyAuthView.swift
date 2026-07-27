//
//  WKWebViewCTKYubiKeyAuthenticationView.swift
//  CBAAuthentication
//
//  Created by Ashish Awasthi on 24/07/26.
//

import SwiftUI
import WebKit
import UIKit

struct WKCTKYubiKeyAuthView: View {
   // https://isdkweb03.ssdevrd.com:8443/ia
    private let cbaURL = URL(string: "https://client.badssl.com/")!

    var body: some View {
        VStack {
            WKCTKYubKeyWrapperView(url: cbaURL)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        }
        .onReceive(NotificationCenter.default.publisher(for: .cbaOpenAppFromLocalNotification)) {_ in
            print("YubiKeyJob: Notification received.")
            guard let jobDetail = JobDataUtil.readFromSharedDefaults() else {
                return
            }
            print("YubiKeyJob: Starting Job")
            let handler = YubiKeyHandler()
            handler.handleIncomingJobOperation(jobData: jobDetail)
        }
    }
}

import SwiftUI
import WebKit
import Security

struct WKCTKYubKeyWrapperView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        context.coordinator.installRefreshControl(on: webView)
        context.coordinator.loadFreshPage()
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let url: URL
        weak var webView: WKWebView?

        init(url: URL) {
            self.url = url
        }

        func installRefreshControl(on webView: WKWebView) {
            let refreshControl = UIRefreshControl()
            refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
            webView.scrollView.refreshControl = refreshControl
        }

        func loadFreshPage() {
            guard let webView else { return }
            clearSession(for: webView) {
                let request = URLRequest(url: self.url, cachePolicy: .reloadIgnoringLocalCacheData)
                webView.load(request)
            }
        }

        @objc
        private func handleRefresh() {
            loadFreshPage()
            webView?.scrollView.refreshControl?.endRefreshing()
        }

        private func clearSession(for webView: WKWebView, completion: @escaping () -> Void) {
            let dataStore = webView.configuration.websiteDataStore
            let allDataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
            dataStore.fetchDataRecords(ofTypes: allDataTypes) { records in
                dataStore.removeData(ofTypes: allDataTypes, for: records) {
                    HTTPCookieStorage.shared.cookies?.forEach {
                        HTTPCookieStorage.shared.deleteCookie($0)
                    }
                    URLCache.shared.removeAllCachedResponses()
                    completion()
                }
            }
        }

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
                                               persistence: .none)
                completionHandler(.useCredential, credential)
            } else {
                print("WKCTKWrapperView: no matching CTK identity — cancelling challenge")
                completionHandler(.cancelAuthenticationChallenge, nil)
            }
        }
    }
}
