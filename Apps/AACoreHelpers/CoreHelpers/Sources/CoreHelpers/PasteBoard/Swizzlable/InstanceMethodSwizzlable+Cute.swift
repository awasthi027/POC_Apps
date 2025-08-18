//
//  InstanceMethodSwizzlable+Cute.swift
//  CoreHelpers
//
//  Created by Ashish Awasthi on 14/08/25.
//

import Foundation

#if os(iOS)
import UIKit
import WebKit
@objc
internal protocol CutActionMethodSwizzlingProvider {
    func cut(_ sender: Any?)
    func chsdkSwizzledCut(_ sender: Any?)
}

@objc
internal protocol CutMethodSwizzledImplementationProvider {
    func cutSelected(_ sender: Any?)
}

internal protocol CutMethodSwizzlable: InstanceMethodSwizzlable {
    static func swizzleCutMethod()
}

extension CutMethodSwizzlable where Self: CutActionMethodSwizzlingProvider {
    
    static func swizzleCutMethod() {
        self.swizzleInstanceMethod(from: #selector(CutActionMethodSwizzlingProvider.cut(_:)),
                                   to: #selector(CutActionMethodSwizzlingProvider.chsdkSwizzledCut(_:)))
    }
}

extension UITextField: CutActionMethodSwizzlingProvider {
    func chsdkSwizzledCut(_ sender: Any?) {
        self.chsdkSwizzledCut(sender)
        self.copyAndCutAdminRestriction()
    }
}
extension UITextView: CutActionMethodSwizzlingProvider {
    func chsdkSwizzledCut(_ sender: Any?) {
        self.chsdkSwizzledCut(sender)
        self.copyAndCutAdminRestriction()
    }
}

extension WKWebView: CutActionMethodSwizzlingProvider {
    
    func chsdkSwizzledCut(_ sender: Any?) {
        self.chsdkSwizzledCopy(sender)
        // Get the selected text via JavaScript
        self.copyAndCutAdminRestriction()
    }
}

#endif
