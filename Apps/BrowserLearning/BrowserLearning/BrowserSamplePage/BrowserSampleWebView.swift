//
//  BrowserSampleWebView.swift
//  ai-concept-learning
//
//  WKWebView wrapper that renders local HTML and reroutes link taps to the
//  injected URL opener logic.
//

import SwiftUI
import WebKit

struct BrowserSampleWebView: UIViewRepresentable {

    let htmlContent: String
    let onOpenURL: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onOpenURL: onOpenURL)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.accessibilityIdentifier = "browserSampleWebView"
        context.coordinator.lastHTMLContent = htmlContent
        webView.loadHTMLString(htmlContent, baseURL: nil)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onOpenURL = onOpenURL
        guard context.coordinator.lastHTMLContent != htmlContent else {
            return
        }
        context.coordinator.lastHTMLContent = htmlContent
        webView.loadHTMLString(htmlContent, baseURL: nil)
    }
}

extension BrowserSampleWebView {
    final class Coordinator: NSObject, WKNavigationDelegate {

        var onOpenURL: (URL) -> Void
        var lastHTMLContent: String = ""

        init(onOpenURL: @escaping (URL) -> Void) {
            self.onOpenURL = onOpenURL
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard navigationAction.navigationType == .linkActivated,
                  let selectedURL = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            onOpenURL(selectedURL)
            decisionHandler(.cancel)
        }
    }
}
