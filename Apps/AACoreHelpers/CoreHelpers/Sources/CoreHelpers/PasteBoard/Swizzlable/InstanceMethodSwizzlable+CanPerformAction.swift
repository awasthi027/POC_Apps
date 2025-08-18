//
//  InstanceMethodSwizzlable+CanPerformAction.swift
//  AWCorePlatformHelpers
//
//  Copyright (c) Omnissa, LLC. All rights reserved.
//  This product is protected by copyright and intellectual property laws in the
//  United States and other countries as well as by international treaties.
//  -- Omnissa Restricted
//

import Foundation

#if os(iOS)
import UIKit
import WebKit

@objc
internal protocol CanPerformActionMethodSwizzlingProvider {
    func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool
    func chsdkSwizzledCanPerformAction(_ action: Selector, withSender sender: Any?) -> Bool
}

internal protocol CanPerformActionMethodSwizzlable: InstanceMethodSwizzlable {
    static func swizzleCanPerformAction()
}

extension CanPerformActionMethodSwizzlable where Self: CanPerformActionMethodSwizzlingProvider {

    static func swizzleCanPerformAction() {
        self.swizzleInstanceMethod(from: #selector(CanPerformActionMethodSwizzlingProvider.canPerformAction(_:withSender:)),
                                   to: #selector(CanPerformActionMethodSwizzlingProvider.chsdkSwizzledCanPerformAction(_:withSender:)))
    }
}

extension UIResponder: CanPerformActionMethodSwizzlingProvider {


    func chsdkSwizzledCanPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        guard CoreHelperManager.shared.supports(action: action) else {
            print("action \(action), sender \(String(describing: sender))")
            //            if var command = sender as? UICommand {
            //                print("\(command.discoverabilityTitle)")
            //            }
            return false
        }
        // If the action is in our supported list, pass it back to the original `canPerformAction` and return.
        let result = self.chsdkSwizzledCanPerformAction(action, withSender: sender)
//        print("result \(action)")
        return result
    }
}

#endif
