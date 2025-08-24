//
//  UIActivityViewController+Swizzle.swift
//  CoreHelpers
//
//  Created by Ashish Awasthi on 18/08/25.
//

#if os(iOS)
import UIKit

internal protocol InitSwizzleSettingProvider {
    static var shouldSwizzleInitializer: Bool { get }
}

/// Helper protocol to swizzle UIActivityViewController initalise method
internal protocol UIActivityViewControllerInitializerSwizzlable: InitSwizzleSettingProvider,
                                                                    InstanceMethodSwizzlable {
    /// Helper func to swizzle initalise method
    static func swizzleUIActivityViewControllerInitActivityMethod()
}

// default implementations for UIActivityViewControllerInitializerSwizzlable protocol
extension UIActivityViewControllerInitializerSwizzlable {
    // flag to check swizzle is needed or not
    static var shouldSwizzleInitializer: Bool {
        // return bool setting from SDKDefaultSettings
        CoreHelperManager.shared.isEnabled
    }

    /// Helper func to swizzle initalise method
    static func swizzleUIActivityViewControllerInitActivityMethod() {
        // swizzle only when setting is enabled in default setting
        // check for default setting from setting plist
        guard self.shouldSwizzleInitializer else {
            // return if swizzle isn't needed
            return
        }
        let originalSelector = #selector(UIActivityViewController.init(activityItems:applicationActivities:))
        let swizzledSelector = #selector(UIActivityViewController.swizzleInit(activityItems:applicationActivities:))
        self.swizzleInstanceMethod(from: originalSelector,
                                   to: swizzledSelector)

    }
}

extension UIActivityViewController {
    /// UIActivityViewController's swizzled implementation
    @objc func swizzleInit(activityItems: [Any], applicationActivities: [UIActivity]?) -> UIActivityViewController {

        // place holder local var to hold activityItems
        var replacedActivityItems = activityItems
        // check restrictions to change the behavior
        if CoreHelperManager.shared.isRestrictionOnActivityController {
            // updated activityItems with message
            print("Application restriction is enabled. Restricting UIActivityViewController")
            replacedActivityItems = [ControllerRestriction.uiActivityControllerRestricted.message]
        }
        // No app restrictions continue with system's implementation
        let vc = self.swizzleInit(activityItems: replacedActivityItems,
                                  applicationActivities: applicationActivities)
            if !CoreHelperManager.shared.isPrintingAllowed {
                if let _ = vc.excludedActivityTypes {
                    vc.excludedActivityTypes?.append(.print)
                } else {
                    vc.excludedActivityTypes = [.print]
                }
            }
        return vc
    }
}

extension UIActivityViewController: UIActivityViewControllerInitializerSwizzlable {
    private static let swizzleOnlyOnce: Swift.Void = {
        UIActivityViewController.swizzleUIActivityViewControllerInitActivityMethod()
    }()

    // Helper method to trigger swizzle from @objc implementation
    @objc
    public static func swizzleRequiredMethods() {
        self.swizzleOnlyOnce
    }
}

#endif
