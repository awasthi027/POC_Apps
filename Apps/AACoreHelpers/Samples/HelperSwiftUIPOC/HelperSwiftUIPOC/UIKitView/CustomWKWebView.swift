//
//  CustomWKWebView.swift
//  HelperSwiftUIPOC
//
//  Created by Ashish Awasthi on 13/08/25.
//

enum JavaScriptStatus {
    case enabled
    case disabled
}

enum WebViewStatus {
    case editable
    case uneditable(JavaScriptStatus)
}

extension WebViewStatus {
    static let htmlStart = "<HTML><HEAD><meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0, shrink-to-fit=no\"></HEAD><body contenteditable=true>"
    static let htmlEnd = "</BODY></HTML>"
    static let dummy_html = """
                           <p>I am editable text with long paragram, You can copy me and select, select all and do your testing\n\n</p>
                           <p>I am very simple and more powerfully greeting hello world\n\n</p>
                           <p>You can add any text for your testing</p>
                           """
    static let htmlString = "\(Self.htmlStart)\(Self.dummy_html)\(Self.htmlEnd)"
}

import SwiftUI
import WebKit

struct CustomWKWebView: UIViewRepresentable {

    let webViewStatus: WebViewStatus
    var url: URL
    
    func makeUIView(context: Context) -> WKWebView {

        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: CGRect.zero,
                                configuration: configuration)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        switch webViewStatus {
        case .editable:
            uiView.loadHTMLString(WebViewStatus.htmlString, baseURL: nil)
        case .uneditable(let jsStatus):
            uiView.configuration.preferences.javaScriptEnabled = jsStatus == .enabled ? true : false
            let request = URLRequest(url: url)
            uiView.load(request)
        }
    }
}
