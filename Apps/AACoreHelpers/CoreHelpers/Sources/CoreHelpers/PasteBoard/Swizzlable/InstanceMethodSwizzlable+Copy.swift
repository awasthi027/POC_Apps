//
//  InstanceMethodSwizzlable+Copy.swift
//  CoreHelpers
//
//  Created by Ashish Awasthi on 13/08/25.
//

import Foundation

#if os(iOS)
import UIKit
import WebKit

@objc
internal protocol CopyActionMethodSwizzlingProvider {
    func copy(_ sender: Any?)
    func chsdkSwizzledCopy(_ sender: Any?)
}

@objc
internal protocol CopyMethodSwizzledImplementationProvider {
    func copySelected(_ sender: Any?)
}

internal protocol CopyMethodSwizzlable: InstanceMethodSwizzlable {
    static func swizzleCopyMethod()
}

extension CopyMethodSwizzlable where Self: CopyActionMethodSwizzlingProvider {
    static func swizzleCopyMethod() {
        self.swizzleInstanceMethod(from: #selector(CopyActionMethodSwizzlingProvider.copy(_:)),
                                   to: #selector(CopyActionMethodSwizzlingProvider.chsdkSwizzledCopy(_:)))
    }
}

extension UITextView: CopyActionMethodSwizzlingProvider {
    func chsdkSwizzledCopy(_ sender: Any?) {
        // Call original copy
        self.chsdkSwizzledCopy(sender)
        self.copyAndCutAdminRestriction()
    }
}

extension UITextField: CopyActionMethodSwizzlingProvider {

    func chsdkSwizzledCopy(_ sender: Any?) {
        self.chsdkSwizzledCopy(sender)
        self.copyAndCutAdminRestriction()
    }
}

extension WKWebView: CopyActionMethodSwizzlingProvider {
    func chsdkSwizzledCopy(_ sender: Any?) {
        self.chsdkSwizzledCopy(sender)
        // Get the selected text via JavaScript
        self.copyAndCutAdminRestriction()
    }
}

#endif
