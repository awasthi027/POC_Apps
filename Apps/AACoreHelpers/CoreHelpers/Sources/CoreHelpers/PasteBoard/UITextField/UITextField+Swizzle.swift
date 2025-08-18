//
//  UITextField+Swizzle.swift
//  CoreHelpers
//
//  Created by Ashish Awasthi on 12/08/25.
//

import Foundation

#if os(iOS)
import UIKit

extension UITextField: CanPerformActionMethodSwizzlable { }

extension UITextField: CopyMethodSwizzlable { }
extension UITextField: CutMethodSwizzlable { }
extension UITextField: PasteMethodSwizzlable { }
extension UITextField: WritingToolsMethodSwizzlable { }

public extension UITextField {

    private static let swizzleOnlyOnce: Swift.Void = {
        UITextField.swizzleCanPerformAction()
        UITextField.swizzleCopyMethod()
        UITextField.swizzleCutMethod()
        UITextField.swizzlePasteMethod()
        UITextField.swizzleWritingToolsMethod()
    }()

    @objc
    static func swizzleRequiredMethods() {
        self.swizzleOnlyOnce
    }
}

#endif
