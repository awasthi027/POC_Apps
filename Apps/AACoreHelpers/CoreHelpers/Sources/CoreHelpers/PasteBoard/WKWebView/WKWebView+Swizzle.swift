//
//  WKWebView+Swizzle.swift
//  CoreHelpers
//
//  Created by Ashish Awasthi on 12/08/25.
//

import Foundation

#if os(iOS)
import WebKit

extension WKWebView: InstanceMethodSwizzlable {
    static var targetedClass: AnyClass? {
        return self
    }
}

extension WKWebView: CanPerformActionMethodSwizzlable { }

extension WKWebView: CopyMethodSwizzlable { }
extension WKWebView: CutMethodSwizzlable { }
extension WKWebView: PasteMethodSwizzlable { }

public extension WKWebView {
    private static let swizzleOnlyOnce: Swift.Void = {
        //WKWebView.swizzleUIDelegate()
        WKWebView.swizzleInitialisation()
        WKWebView.swizzleCanPerformAction()
        WKWebView.swizzleCopyMethod()
        WKWebView.swizzleCutMethod()
        WKWebView.swizzlePasteMethod()
    }()

    @objc
    static func swizzleRequiredMethods() {
        self.swizzleOnlyOnce
    }
}
#endif
