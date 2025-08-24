//
//  UIDocumentInteractionController+Swizzle.swift
//  CoreHelpers
//
//  Created by Ashish Awasthi on 19/08/25.
//

import Foundation
#if os(iOS)
import UIKit

// Helper closure type to copy the document interaction contoller's initialization method
internal typealias UIDocumentControllerInitHandler = @convention(c) (AnyObject, Selector, URL) -> UIDocumentInteractionController

/// Protocol helper to swizzle DocumentInteractionController  Init method
internal protocol DocumentInteractionControllerInitializerSwizzlable: InitSwizzleSettingProvider,
                                                                      InstanceMethodSwizzlable {
    // variable to hold the closure
    static var documentInteractionControllerSystemImplementation: UIDocumentControllerInitHandler? { get set }

    static func extractDocumentInteractionControllerInitializerMethodImplementation() -> Bool
    /// Helper func to swizzle init method
    static func swizzleInteractionControllerInitURLMethod()
}

@available(iOSApplicationExtension, unavailable)
extension DocumentInteractionControllerInitializerSwizzlable {

    static var shouldSwizzleInitializer: Bool {
        // return setting in default setting
        return true
    }

    /// Helper func to copy the UIDocumentInteractionController init method to `documentInteractionControllerSystemImplementation` closure
    static func extractDocumentInteractionControllerInitializerMethodImplementation() -> Bool {
        // get UIDocumentInteractionController init method
        guard let origMethod = class_getClassMethod(UIDocumentInteractionController.self,
                                                    #selector(UIDocumentInteractionController.init(url:))) else {
            print("Not able to get UIDocumentInteractionController's initializer method")
                                                        return false
        }
        // get UIDocumentInteractionController init method implementation
        let imp = method_getImplementation(origMethod)
        // cast imp to closure
        self.documentInteractionControllerSystemImplementation = unsafeBitCast(imp, to: UIDocumentControllerInitHandler.self)
        return self.documentInteractionControllerSystemImplementation != nil
    }

    /// Helper func to swizzle UIDocumentInteractionController init implementation
    static func swizzleInteractionControllerInitURLMethod() {
        // swizzle only when setting is enabled in default setting
        // check for default setting from setting plist
        guard self.shouldSwizzleInitializer else {
            return
        }
        // assign original implememtation
        guard self.extractDocumentInteractionControllerInitializerMethodImplementation() else {
            // error log if not able to extract UIDocumentInteractionController original imp
            print("unable to get UIDocumentInteractionController's initializer method implementation")
            return
        }
        let originalSelector =  #selector(UIDocumentInteractionController.init(url:))
        let swizzledSelector =  #selector(UIDocumentInteractionController.swizzledDocumentInteractionControllerInit(url:))
        self.swizzleClassMethod(from: originalSelector,
                                   to: swizzledSelector)


    }
}

@available(iOSApplicationExtension, unavailable)
extension UIDocumentInteractionController {
    /// UIDocumentInteractionController swizzled init method implementation
    @objc
    class func swizzledDocumentInteractionControllerInit(url: URL) -> UIDocumentInteractionController {
        // check restrictions to change the behavior
        guard self.appRestrictionEnabled else {
            // No app restrictions continue with system's implementation
            return self.swizzledDocumentInteractionControllerInit(url: url)
        }

        print("Application restriction is enabled. Restricting UIDocumentInteractionController")
        let documentInteractionController = DocumentInteractionController(url: url)
        let allowedApplications: [String] = CoreHelperManager.shared.documentShareAllowedWithApps
        documentInteractionController.allowedApps = allowedApplications
        // Return DocumentInteractionController instance
        return documentInteractionController
    }

    /// Helper func to call `UIDocumentInteractionController's` system implementation
    @objc
    class func original_DocumentInteractionControllerInit(url: URL) -> UIDocumentInteractionController {

        // check for originalInitialiseImp
        guard let imp = self.documentInteractionControllerSystemImplementation else {
            // No app restrictions continue with system's implementation
            return UIDocumentInteractionController(url: url)
        }
        // Call to closure to get UIDocumentInteractionController
        return imp(self, #selector(UIDocumentInteractionController.init(url:)), url)
    }
}

@available(iOSApplicationExtension, unavailable)
/// UIDocumentInteractionController extension to confirm RestrictionSettingsProvider and DocumentInteractionControllerInitializerSwizzlable
extension UIDocumentInteractionController: DocumentInteractionControllerInitializerSwizzlable {
    static var documentInteractionControllerSystemImplementation: UIDocumentControllerInitHandler?

    // return restructions from the `DocumentInteractionController`
    static var appRestrictionEnabled: Bool {
        return true
    }
}

@available(iOSApplicationExtension, unavailable)
public extension UIDocumentInteractionController {

    private static let swizzleOnlyOnce: Swift.Void = {
        UIDocumentInteractionController.swizzleInteractionControllerInitURLMethod()
    }()

    /// Helper method to trigger swizzle from @objc implementation
    @objc
    static func swizzleRequiredMethods() {
        self.swizzleOnlyOnce
    }
}
#endif
