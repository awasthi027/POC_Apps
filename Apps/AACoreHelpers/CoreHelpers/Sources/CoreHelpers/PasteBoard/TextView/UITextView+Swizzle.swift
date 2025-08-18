//
//  UITextView+Swizzle.swift
//  CoreHelpers
//
//  Created by Ashish Awasthi on 12/08/25.
//

import Foundation
#if os(iOS)
import UIKit

extension UITextView: CanPerformActionMethodSwizzlable { }

extension UITextView: CopyMethodSwizzlable { }
extension UITextView: CutMethodSwizzlable { }
extension UITextView: PasteMethodSwizzlable { }

public extension UITextView {

    private static let swizzleOnlyOnce: Swift.Void = {
        UITextView.swizzleCanPerformAction()
        UITextView.swizzleCopyMethod()
        UITextView.swizzleCutMethod()
        UITextView.swizzlePasteMethod()
    }()

    @objc
    static func swizzleRequiredMethods() {
        self.swizzleOnlyOnce
    }
}

#endif
