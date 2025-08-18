//
//  Untitled.swift
//  CoreHelpers
//
//  Created by Ashish Awasthi on 13/08/25.
//

import Foundation

#if os(iOS)
import UIKit
import WebKit

@objc
internal protocol PasteActionMethodSwizzlingProvider {
    func paste(_ sender: Any?)
    func chsdkSwizzledPaste(_ sender: Any?)
}

@objc
internal protocol PasteMethodSwizzledImplementationProvider {
    func pasteSelected(_ sender: Any?)
}

internal protocol PasteMethodSwizzlable: InstanceMethodSwizzlable {
    static func swizzlePasteMethod()
    func swizzled_paste(_ sender: Any?)

}

extension PasteMethodSwizzlable where Self: PasteActionMethodSwizzlingProvider {

    static func swizzlePasteMethod() {
        self.swizzleInstanceMethod(from: #selector(PasteActionMethodSwizzlingProvider.paste(_:)),
                                   to: #selector(PasteActionMethodSwizzlingProvider.chsdkSwizzledPaste(_:)))
    }
}

extension UITextField: PasteActionMethodSwizzlingProvider {
    
    func chsdkSwizzledPaste(_ sender: Any?) {
        self.swizzled_paste(nil)
    }

    @objc func swizzled_paste(_ sender: Any?) {
        self.pasteAdminRestriction()
    }
}

extension UITextView: PasteActionMethodSwizzlingProvider {

    func chsdkSwizzledPaste(_ sender: Any?) {
        self.swizzled_paste(nil)
    }

    @objc func swizzled_paste(_ sender: Any?) {
        self.pasteAdminRestriction()
    }
}

extension WKWebView: PasteActionMethodSwizzlingProvider {
    func chsdkSwizzledPaste(_ sender: Any?) {
        self.swizzled_paste(nil)
    }

    @objc func swizzled_paste(_ sender: Any?) {
        self.pasteAdminRestriction()
    }
}

#endif

