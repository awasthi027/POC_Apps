//
//  Instance+WebView.swift
//  CoreHelpers
//
//  Created by Ashish Awasthi on 12/08/25.
//
#if os(iOS)
import WebKit
extension WKWebView {

    static func swizzleInitialisation() {
        self.swizzleInstanceMethod(from: #selector(WKWebView.init(frame:configuration:)),
                                   to: #selector(WKWebView.chsdkSwizzledInit(frame:configuration:)))
    }
}

public extension WKWebView {

    @objc func chsdkSwizzledInit(frame: CGRect,
                                 configuration: WKWebViewConfiguration) -> WKWebView? {
        if #available(iOS 18.0, *) {
            if !CoreHelperManager.shared.isWritingToolsAllowed {
                configuration.writingToolsBehavior = UIWritingToolsBehavior.none
            }
        }
        return chsdkSwizzledInit(frame: frame,
                                 configuration: configuration)
    }
}
#endif
