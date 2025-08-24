//
//  CHDocumentInteractionController.swift
//  CoreHelpers
//
//  Created by Ashish Awasthi on 19/08/25.
//

import Foundation
import UIKit
public protocol RestrictionSettingsProvider {
    static var appRestrictionEnabled: Bool { get }
}

@available(iOSApplicationExtension, unavailable)
@objc(AWDocumentInteractionController)
final public class DocumentInteractionController: UIDocumentInteractionController {

    struct Restrictions: RestrictionSettingsProvider {
        public static var appRestrictionEnabled: Bool {
            return CoreHelperManager.shared.isRestrictionOnUIDocInteractionController
        }
    }

    public static var restrictions: RestrictionSettingsProvider.Type = DocumentInteractionController.Restrictions.self

    internal let fileURL: URL
    fileprivate let realInstance: UIDocumentInteractionController
    fileprivate let alertMessage: String
    fileprivate let qlPreviewViewController: CHQLPreviewController
    fileprivate var alertWindow: UIWindow?

    @objc public var allowedApps: [String]

    @objc public init(url: URL) {
        self.fileURL = url
        self.realInstance = UIDocumentInteractionController.original_DocumentInteractionControllerInit(url: self.fileURL)
        self.alertMessage = ControllerRestriction.uiDocumentInteractionControllerRestricted.message
        if !CoreHelperManager.shared.isPrintingAllowed {
            //AWQLPreviewController should not show print option
            self.qlPreviewViewController = CHQLPreviewController(with: self.fileURL,
                                                                 shouldAllowPrint: false)
        } else {
            self.qlPreviewViewController = CHQLPreviewController(with: self.fileURL)
        }

        self.allowedApps = []
        super.init()

        self.realInstance.delegate = self
    }

    fileprivate var restrictFileName: String {
        let filename = "RestrictedFile.pdf"
        return filename
    }
}

// MARK: Static Variables and Functions
@available(iOSApplicationExtension, unavailable)
extension DocumentInteractionController {
    public static func interactionController(with url: URL) -> DocumentInteractionController {
        return DocumentInteractionController(url: url)
    }
}

// MARK: Instance Properties Bridging
@available(iOSApplicationExtension, unavailable)
public extension DocumentInteractionController {
    @objc override var url: URL? {
        get {
            return self.realInstance.url
        }
        set {
            self.realInstance.url = newValue
        }
    }

    @objc override var uti: String? {
        get {
            return self.realInstance.uti
        }
        set {
            self.realInstance.uti = newValue
        }
    }

    @objc override var name: String? {
        get {
            return self.realInstance.name
        }
        set {
            self.realInstance.name = newValue
        }
    }

    @objc override var icons: [UIImage] {
        return self.realInstance.icons
    }

    @objc override var annotation: Any? {
        get {
            return self.realInstance.annotation
        }
        set {
            self.realInstance.annotation = newValue
        }
    }

    @objc override var gestureRecognizers: [UIGestureRecognizer] {
        return self.realInstance.gestureRecognizers
    }
}

// MARK: Instance Functions Bridging
@available(iOSApplicationExtension, unavailable)
public extension DocumentInteractionController {
    fileprivate func provideFakeFileURLIfRequired() {
        if DocumentInteractionController.restrictions.appRestrictionEnabled {
            let emptyFilePathURL = FileUtility.shared.temporaryDirectory(fileName: self.restrictFileName)
            if !FileUtility.shared.pdfExists(fileName: self.restrictFileName) {
               let isCreated = FileUtility.shared.writePDF(fileName: self.restrictFileName,
                                                           text: "The administrator doesn't allow this document to be opened in the selected app.")
                if isCreated {
                    print("Empty PDF file created at \(String(describing: emptyFilePathURL))")
                }
            }
            self.realInstance.url = emptyFilePathURL
        }
    }

    override func presentOptionsMenu(from rect: CGRect, in view: UIView, animated: Bool) -> Bool {
        self.provideFakeFileURLIfRequired()
        return self.realInstance.presentOptionsMenu(from: rect, in: view, animated: animated)
    }

    override func presentOptionsMenu(from item: UIBarButtonItem, animated: Bool) -> Bool {
        self.provideFakeFileURLIfRequired()
        return self.realInstance.presentOptionsMenu(from: item, animated: animated)
    }

    override func presentPreview(animated: Bool) -> Bool {
        var keyWindow: UIWindow?
        ensureOnMainQueue {
            keyWindow = (UIApplication.shared as KeyWindowGettable).keyUIWindow
        }

        guard let rootViewController = keyWindow?.rootViewController else {
            return false
        }

        let topVC = topMostViewController(rootViewController)
        if let navVc = topVC as? UINavigationController {
            navVc.pushViewController(qlPreviewViewController, animated: animated)
        } else {
            /// If the top view controller is not part of a navigation controller,
            /// simply present the preview controller modally.
            //let navVc = //UINavigationController(rootViewController: qlPreviewViewController)
            ensureOnMainQueue {
                topVC.present(qlPreviewViewController, animated: animated)
            }
        }
        return true
    }

    /// Traverse to the top-most view controller in the hierarchy.
    /// If it is a UINavigationController or is embedded within one, return the navigation controller or return the top most
    func topMostViewController(_ root: UIViewController) -> UIViewController {
        var current = root

        while true {
            if let presented = current.presentedViewController {
                current = presented
            } else if let split = current as? UISplitViewController, let last = split.viewControllers.last {
                current = last
            } else if let tab = current as? UITabBarController, let selected = tab.selectedViewController {
                current = selected
            } else if let nav = current as? UINavigationController, let visible = nav.visibleViewController {
                current = visible
            } else {
                break
            }
        }
        // If the topmost view controller is part of a navigation controller, return that
        return current.navigationController ?? current
    }

    override func presentOpenInMenu(from rect: CGRect, in view: UIView, animated: Bool) -> Bool {
        self.provideFakeFileURLIfRequired()
        return self.realInstance.presentOpenInMenu(from: rect, in: view, animated: animated)
    }

    override func presentOpenInMenu(from item: UIBarButtonItem, animated: Bool) -> Bool {
        self.provideFakeFileURLIfRequired()
        return self.realInstance.presentOpenInMenu(from: item, animated: animated)
    }

    override func dismissPreview(animated: Bool) {
        self.realInstance.dismissPreview(animated: animated)
    }

    override func dismissMenu(animated: Bool) {
        self.realInstance.dismissMenu(animated: animated)
    }
}

// MARK: Delegate Functions Bridging
@available(iOSApplicationExtension, unavailable)
extension DocumentInteractionController: UIDocumentInteractionControllerDelegate {
    public func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        guard let previewController = self.retrieveDelegateMethod(using: { $0.documentInteractionControllerViewControllerForPreview }) else {
            print( "The delegate does not implement the function documentInteractionControllerViewControllerForPreview(_:) ")
            if let uiViewController = self.delegate as? UIViewController {
                return uiViewController
            } else {
                return UIViewController()
            }
        }
        return previewController(self.realInstance)
    }

    public func documentInteractionControllerRectForPreview(_ controller: UIDocumentInteractionController) -> CGRect {
        self.attempt(delegateMethod: { $0.documentInteractionControllerRectForPreview },
                     methodName: "documentInteractionControllerRectForPreview(_:)",
                     fallback: CGRect(x: 0.0, y: 0.0, width: 0.0, height: 0.0))
    }

    public func documentInteractionControllerViewForPreview(_ controller: UIDocumentInteractionController) -> UIView? {
        self.attempt(delegateMethod: { $0.documentInteractionControllerViewForPreview },
                     methodName: "documentInteractionControllerViewForPreview(_:)",
                     fallback: nil)
    }

    public func documentInteractionControllerWillBeginPreview(_ controller: UIDocumentInteractionController) {
        self.attempt(delegateMethod: { $0.documentInteractionControllerWillBeginPreview },
                     methodName: "documentInteractionControllerWillBeginPreview(_:)")
    }

    public func documentInteractionControllerDidEndPreview(_ controller: UIDocumentInteractionController) {
        self.attempt(delegateMethod: { $0.documentInteractionControllerDidEndPreview },
                     methodName: "documentInteractionControllerDidEndPreview(_:)")
    }

    public func documentInteractionControllerWillPresentOptionsMenu(_ controller: UIDocumentInteractionController) {
        self.attempt(delegateMethod: { $0.documentInteractionControllerWillPresentOptionsMenu },
                     methodName: "documentInteractionControllerWillPresentOptionsMenu(_:)")
    }

    public func documentInteractionControllerDidDismissOptionsMenu(_ controller: UIDocumentInteractionController) {
        self.removeEmptyFileIfPresent()
        self.attempt(delegateMethod: { $0.documentInteractionControllerDidDismissOptionsMenu },
                     methodName: "documentInteractionControllerDidDismissOptionsMenu(_:)")
    }

    public func documentInteractionControllerWillPresentOpenInMenu(_ controller: UIDocumentInteractionController) {
        guard self.uti != nil else {
            print("The UTI cannot be nil if you want to present the Open In Menu")
            return
        }

        self.attempt(delegateMethod: { $0.documentInteractionControllerWillPresentOpenInMenu },
                     methodName: "documentInteractionControllerWillPresentOpenInMenu(_:)")
    }

    public func documentInteractionControllerDidDismissOpenInMenu(_ controller: UIDocumentInteractionController) {
        self.removeEmptyFileIfPresent()
        self.attempt(delegateMethod: { $0.documentInteractionControllerDidDismissOpenInMenu },
                     methodName: "documentInteractionControllerDidDismissOpenInMenu(_:)")
    }

    static let dummyFilepath = "dummyfileURL"
    public func documentInteractionController(_ controller: UIDocumentInteractionController, willBeginSendingToApplication application: String?) {

        guard self.isAppAllowed(with: application) else {
            controller.url = URL(fileURLWithPath: DocumentInteractionController.dummyFilepath)
            return
        }

        guard let willBeginSendingToApplication = self.retrieveDelegateMethod(using: { $0.documentInteractionController(_: willBeginSendingToApplication:) })
        else {
            print( "The delegate does not implement the function documentInteractionController(_: willBeginSendingToApplication:) ")
            return
        }


        willBeginSendingToApplication(controller, application)
    }

    public func documentInteractionController(_ controller: UIDocumentInteractionController, didEndSendingToApplication application: String?) {
        self.attempt(delegateMethod: { $0.documentInteractionController(_: didEndSendingToApplication:) },
                     with: application,
                     methodName: "documentInteractionController(_:, didEndSendingToApplication:String?)")
    }
}

// MARK: Helper Functions
@available(iOSApplicationExtension, unavailable)
internal extension DocumentInteractionController {
    func isAppAllowed(with appBundleID: String?) -> Bool {
        guard DocumentInteractionController.restrictions.appRestrictionEnabled else {
            self.realInstance.url = self.fileURL
            return true
        }

        guard !self.allowedApps.isEmpty else {
            print( "no app is allowed")
            return false
        }

        guard let appBundleID = appBundleID else {
            print( "appBundleID is nil")
            return false
        }

        let match = self.allowedApps.first {
            // Here we check if the app bundle id has a prefix that match one of the items in the allowed apps list
            // We do this to include not only the app but also the app extension
            // The app bundle id usually comes as
            // com.orgnazation.appName
            // The app extension id usually comes as
            // com.orgnazation.appName.extensionName
            // So if an app extension has a prefix that matches one of the app id inside the allowed apps list, then its extension is allowed as well
            appBundleID.lowercased().hasPrefix($0.lowercased())
        }

        guard match != nil else {
            print( "appBundleID is not inside the allowed list")
            return false
        }

        self.realInstance.url = self.fileURL
        return true
    }


    func removeEmptyFileIfPresent() {
        let status = FileUtility.shared.deletePDF(fileName: self.restrictFileName)
        print("Temporary empty PDF file deleted: \(status)")
    }

   
}

// MARK: Delegate Protocol-Optional Method Handling
@available(iOSApplicationExtension, unavailable)
internal extension DocumentInteractionController {

    /// Attempts to invoke a method on the delegate. This function will log debug messages if 1) the delegate is nil and
    /// 2) if the delegate does not implement the protocol-optional method.
    /// N.B. This function automatically supplies the UIDocumentInteractionController argument to the reteived function
    /// - Parameters:
    ///  - retreiver: a block that retrieves the optional method to attempt
    ///  - methodName: the name of the optional method for logging
    private func attempt(delegateMethod retreiver: (UIDocumentInteractionControllerDelegate) -> ((UIDocumentInteractionController) -> Void)?,
                         methodName: String) {
        guard let function = self.retrieveDelegateMethod(using: retreiver) else {
            print( "The delegate does not implement the function \(methodName)")
            return
        }

        function(self.realInstance)
    }

    /// Attempts to invoke a method on the delegate. This function will log debug messages if 1) the delegate is nil and
    /// 2) if the delegate does not implement the protocol-optional method.
    /// N.B. This function automatically supplies the UIDocumentInteractionController argument to the reteived function
    /// - Parameters:
    ///  - retreiver: a block that retrieves the optional method to attempt
    ///  - methodName: the name of the optional method for logging
    private func attempt<R>(delegateMethod retreiver: (UIDocumentInteractionControllerDelegate) -> ((UIDocumentInteractionController) -> R)?,
                            methodName: String,
                            fallback: R) -> R {
        guard let function = self.retrieveDelegateMethod(using: retreiver) else {
            print("The delegate does not implement the function \(methodName)")
            return fallback
        }

        return function(self.realInstance)
    }

    /// Attempts to invoke a method on the delegate. This function will log debug messages if 1) the delegate is nil and
    /// 2) if the delegate does not implement the protocol-optional method.
    /// N.B. This function automatically supplies the UIDocumentInteractionController argument to the reteived function
    /// - Parameters:
    ///  - retreiver: a block that retrieves the optional method to attempt
    ///  - arg: the second argument to the function
    ///  - methodName: the name of the optional method for logging
    private func attempt<A>(delegateMethod retreiver: (UIDocumentInteractionControllerDelegate) -> ((UIDocumentInteractionController, A) -> Void)?,
                            with arg: A,
                            methodName: String) {
        guard let function = self.retrieveDelegateMethod(using: retreiver) else {
            print("The delegate does not implement the function \(methodName)")
            return
        }

        function(self.realInstance, arg)
    }

    /// Retrieves an optional value from the delegate using the supplied block. This function is intended for use in retrieving protocol-optional
    /// methods from the delegate. If the delegate is nil, this function will create a debug log and return nil.
    /// - Parameter retriever: a block to retrieve the optional value
    private func retrieveDelegateMethod<T>(using retriever: (UIDocumentInteractionControllerDelegate) -> T?) -> T? {
        if self.delegate == nil {
            print( "The UIDocumentInteractionControllerDelegate is nil")
        }
        return self.delegate.flatMap(retriever)
    }
}
