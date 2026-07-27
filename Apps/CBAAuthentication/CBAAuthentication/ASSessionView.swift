//
//  ASSessionView.swift
//  CBAAuthentication
//

import SwiftUI
import WebKit
import AuthenticationServices

struct ASSessionView: View {
    private let cbaURL = URL(string: "https://client.badssl.com/")!

    @State private var statusMessage = "Run Phase 1 to trigger the cert challenge in WKWebView."
    @State private var authSession: ASWebAuthenticationSession?
    @State private var anchorProvider: FixedPresentationAnchorProvider?
    @State private var launchedASWebAuth = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WKWebView challenge -> ASWebAuthenticationSession")
                .font(.headline)

            Text(statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            WKPhaseView(
                url: cbaURL,
                onStatus: { statusMessage = $0 },
                onComplete: {
                    if !launchedASWebAuth {
                        launchedASWebAuth = true
                        launchASWebAuthenticationSession()
                    }
                }
            )
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )

            Spacer()
        }
        .padding()
        .navigationTitle("ASWebAuthenticationSession")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            authSession?.cancel()
            authSession = nil
            anchorProvider = nil
        }
    }

    private func launchASWebAuthenticationSession() {
        guard let anchor = ForegroundWindowLocator.activeKeyWindow() else {
            statusMessage = "Cannot start ASWebAuthenticationSession: no foreground-active UIWindowScene. Bring app to foreground and retry."
            launchedASWebAuth = false
            return
        }

        statusMessage = "Launching ASWebAuthenticationSession. OS should present certificate picker."

        let session = ASWebAuthenticationSession(url: cbaURL, callbackURLScheme: "cbademo") { callbackURL, error in
            DispatchQueue.main.async {
                self.authSession = nil
                self.anchorProvider = nil

                if let error = error as? ASWebAuthenticationSessionError {
                    if error.code == .canceledLogin {
                        self.statusMessage = "ASWebAuthenticationSession cancelled by user."
                    } else {
                        self.statusMessage = "ASWebAuthenticationSession failed: \(error.localizedDescription)"
                    }
                    self.launchedASWebAuth = false
                    return
                }

                if let callbackURL {
                    self.statusMessage = "ASWebAuthenticationSession completed with callback: \(callbackURL.absoluteString)"
                } else {
                    self.statusMessage = "ASWebAuthenticationSession finished without callback URL."
                }
            }
        }

        let provider = FixedPresentationAnchorProvider(anchor: anchor)
        anchorProvider = provider
        session.presentationContextProvider = provider
        session.prefersEphemeralWebBrowserSession = false
        authSession = session
        session.start()
    }
}

private struct WKPhaseView: UIViewRepresentable {
    let url: URL
    let onStatus: (String) -> Void
    let onComplete: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onStatus: onStatus, onComplete: onComplete)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url == nil {
            webView.load(URLRequest(url: url))
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let onStatus: (String) -> Void
        private let onComplete: () -> Void
        private var didReport = false

        init(onStatus: @escaping (String) -> Void,
             onComplete: @escaping () -> Void) {
            self.onStatus = onStatus
            self.onComplete = onComplete
        }

        func webView(_ webView: WKWebView,
                     didReceive challenge: URLAuthenticationChallenge,
                     completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate else {
                completionHandler(.performDefaultHandling, nil)
                return
            }

            onStatus("WKWebView received client-cert challenge. Intentionally cancelling and handing off to ASWebAuthenticationSession.")
            completionHandler(.cancelAuthenticationChallenge, nil)
        }

        func webView(_ webView: WKWebView,
                     didFailProvisionalNavigation _: WKNavigation!,
                     withError error: Error) {
            guard !didReport else { return }
            didReport = true
            onStatus("WKWebView failed as expected: \(error.localizedDescription)")
            onComplete()
        }

        func webView(_ webView: WKWebView,
                     didFail _: WKNavigation!,
                     withError error: Error) {
            guard !didReport else { return }
            didReport = true
            onStatus("WKWebView failed as expected: \(error.localizedDescription)")
            onComplete()
        }
    }
}

 enum ForegroundWindowLocator {
    static func activeKeyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })?
            .windows.first(where: { $0.isKeyWindow })
    }
}

final class FixedPresentationAnchorProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    private let anchor: ASPresentationAnchor

    init(anchor: ASPresentationAnchor) {
        self.anchor = anchor
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        anchor
    }
}

#Preview {
    NavigationStack { ASSessionView() }
}
