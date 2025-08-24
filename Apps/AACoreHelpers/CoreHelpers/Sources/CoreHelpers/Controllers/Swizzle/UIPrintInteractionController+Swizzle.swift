//
//  UIPrintInteractionController+Swizzle.swift
//  CoreHelpers
//
//  Created by Ashish Awasthi on 24/08/25.
//

#if os(iOS)
import Foundation
import UIKit

internal typealias UIPrintInteractionControllerSharedInstanceHandler = @convention(c) (AnyObject, Selector) -> UIPrintInteractionController

internal protocol UIPrintInteractionControllerSharedInstanceSwizzlable: InstanceMethodSwizzlable {
    static var shouldSwizzleSharedInstance: Bool { get }
    static var uiPrintInteractionControllerSharedSystemInstance: UIPrintInteractionControllerSharedInstanceHandler? { get set }
    static func swizzleUIPrintInteractionControllerSharedInstanceMethod()
    static func extractUIPrintInteractionControllerSharedInstanceMethod() -> Bool
}

extension UIPrintInteractionControllerSharedInstanceSwizzlable {
    static var shouldSwizzleSharedInstance: Bool {
        return true
    }

    static func extractUIPrintInteractionControllerSharedInstanceMethod() -> Bool {
        guard let originalMethod = class_getClassMethod(UIPrintInteractionController.self,
                                                        #selector(getter: UIPrintInteractionController.shared)) else {
            print("Not able to get UIPrintInteractionController's initializer method")
            return false
        }
        // get UIPrintInteractionController init method implementation
        let implementation = method_getImplementation(originalMethod)
        self.uiPrintInteractionControllerSharedSystemInstance = unsafeBitCast(implementation,
                                                                              to: UIPrintInteractionControllerSharedInstanceHandler.self)
        return self.uiPrintInteractionControllerSharedSystemInstance != nil
    }

    static func swizzleUIPrintInteractionControllerSharedInstanceMethod() {
        guard self.shouldSwizzleSharedInstance else {
            return
        }

        guard self.extractUIPrintInteractionControllerSharedInstanceMethod() else {
            return
        }

        let originalSelector =  #selector(getter: UIPrintInteractionController.shared)
        let swizzledSelector =   #selector(getter: UIPrintInteractionController.swizzledPrintInteractionControllerSharedInstance)
        self.swizzleClassMethod(from: originalSelector,
                                   to: swizzledSelector)
    }
}


extension UIPrintInteractionController: UIPrintInteractionControllerSharedInstanceSwizzlable {
    static var uiPrintInteractionControllerSharedSystemInstance: UIPrintInteractionControllerSharedInstanceHandler? = nil

    static var isPrintRestrictionEnabled: Bool {
        return CoreHelperManager.shared.isRestrictionUIPrintInteractionController
    }

    @objc class var swizzledPrintInteractionControllerSharedInstance: UIPrintInteractionController {
        guard self.isPrintRestrictionEnabled else {
            return self.swizzledPrintInteractionControllerSharedInstance
        }
        return PrintInteractionController.shared
    }

    @objc class func uiPrintInteractionControllerSystemImplementation() -> UIPrintInteractionController {
        // check for originalInitialiseImp
        guard let originalImp = self.uiPrintInteractionControllerSharedSystemInstance else {
            // No app restrictions continue with system's implementation
            return UIPrintInteractionController.shared
        }
        // Call to closure to get UIPrintInteractionController
        return originalImp(self, #selector(getter: UIPrintInteractionController.shared))
    }
}


public extension UIPrintInteractionController {
    private static let swizzleOnlyOnce: () = {
        UIPrintInteractionController.swizzleUIPrintInteractionControllerSharedInstanceMethod()
    }()

    /// Helper method to trigger swizzle from @objc implementation
    @objc static func swizzleRequiredMethods() {
        self.swizzleOnlyOnce
    }
}
#endif
