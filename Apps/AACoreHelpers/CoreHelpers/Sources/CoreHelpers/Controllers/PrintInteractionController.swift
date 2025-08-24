//
//  PrintInteractionController.swift
//  CoreHelpers
//
//  Created by Ashish Awasthi on 24/08/25.
//

import Foundation
import UIKit
@objc final public class PrintInteractionController: UIPrintInteractionController {

    private static let uiPrintInteractionController = UIPrintInteractionController.uiPrintInteractionControllerSystemImplementation()
    private static let sharedInstance: PrintInteractionController = PrintInteractionController()


    struct Restrictions: RestrictionSettingsProvider {
        public static var appRestrictionEnabled: Bool {
            return CoreHelperManager.shared.isRestrictionUIPrintInteractionController
        }
    }

    public static var restrictions: RestrictionSettingsProvider.Type = PrintInteractionController.Restrictions.self


    private override init() {
        // prevent init as all API calls must happen via the `shared` instance
    }

    @objc public override class var shared: UIPrintInteractionController {
        return self.sharedInstance
    }

    @objc public override var printInfo: UIPrintInfo? {
        get {
            return Self.uiPrintInteractionController.printInfo
        }
        set {
            Self.uiPrintInteractionController.printInfo = newValue
        }
    }

    @objc public weak override var delegate: UIPrintInteractionControllerDelegate? {
        get {
            return Self.uiPrintInteractionController.delegate
        }
        set {
            Self.uiPrintInteractionController.delegate = newValue
        }
    }

    @objc public override var showsNumberOfCopies: Bool {
        get {
            return Self.uiPrintInteractionController.showsNumberOfCopies
        }
        set {
            Self.uiPrintInteractionController.showsNumberOfCopies = newValue
        }
    }

    @objc public override var showsPaperSelectionForLoadedPapers: Bool {
        get {
            return Self.uiPrintInteractionController.showsPaperSelectionForLoadedPapers
        }
        set {
            Self.uiPrintInteractionController.showsPaperSelectionForLoadedPapers = newValue
        }
    }

    @objc public override var printPaper: UIPrintPaper? {
        return Self.uiPrintInteractionController.printPaper
    }

    @objc public override var printPageRenderer: UIPrintPageRenderer? {
        get {
            return Self.uiPrintInteractionController.printPageRenderer
        }
        set {
            Self.uiPrintInteractionController.printPageRenderer = newValue
        }
    }

    @objc public override var printFormatter: UIPrintFormatter? {
        get {
            return Self.uiPrintInteractionController.printFormatter
        }
        set {
            Self.uiPrintInteractionController.printFormatter = newValue
        }
    }

    @objc public override var printingItem: Any? {
        get {
            return Self.uiPrintInteractionController.printingItem
        }
        set {
            Self.uiPrintInteractionController.printingItem = newValue
        }
    }

    @objc public override var printingItems: [Any]? {
        get {
            return Self.uiPrintInteractionController.printingItems
        }
        set {
            Self.uiPrintInteractionController.printingItems = newValue
        }
    }

    @objc public override func present(from item: UIBarButtonItem, animated: Bool,
                                       completionHandler completion: UIPrintInteractionController.CompletionHandler? = nil) -> Bool {
        guard PrintInteractionController.isPrintRestrictionEnabled else {
            //no restriction is enabled. Proceeding with present
            return Self.uiPrintInteractionController.present(from: item, animated: animated, completionHandler: completion)
        }
        //Restriction is enabled. So, proceeding with blocking user from printing
        return self.blockUserFromPrinting(completion: completion)
    }

    @objc public override func present(from rect: CGRect, in view: UIView, animated: Bool,
                                       completionHandler completion: UIPrintInteractionController.CompletionHandler? = nil) -> Bool {
        guard PrintInteractionController.isPrintRestrictionEnabled else {
            //no restriction is enabled. Proceeding with present
            return Self.uiPrintInteractionController.present(from: rect, in: view, animated: animated, completionHandler: completion)
        }
        //Restriction is enabled. So, proceeding with blocking user from printing
        return self.blockUserFromPrinting(completion: completion)
    }

    @objc public override func present(animated: Bool, completionHandler completion: UIPrintInteractionController.CompletionHandler? = nil) -> Bool {
        guard PrintInteractionController.isPrintRestrictionEnabled else {
            //no restriction is enabled. Proceeding with present
            return Self.uiPrintInteractionController.present(animated: animated, completionHandler: completion)
        }
        //Restriction is enabled. So, proceeding with blocking user from printing
        return self.blockUserFromPrinting(completion: completion)
    }

    @objc public override func print(to printer: UIPrinter, completionHandler completion: UIPrintInteractionController.CompletionHandler? = nil) -> Bool {
        guard PrintInteractionController.isPrintRestrictionEnabled else {
            //no restriction is enabled. Proceeding with print
            return Self.uiPrintInteractionController.print(to: printer, completionHandler: completion)
        }
        //Restriction is enabled. So, proceeding with blocking user from printing
        return self.blockUserFromPrinting(completion: completion)
    }

    @objc public override func dismiss(animated: Bool) {
        Self.uiPrintInteractionController.dismiss(animated: animated)
    }
}

private extension PrintInteractionController {

    ///  This function will block the printing action
    /// - Parameters:
    ///  - completion: completion that has to be called when printing is blocked
    /// - return:  Bool. Returns false since printing has to be blocked
    func blockUserFromPrinting(completion: UIPrintInteractionController.CompletionHandler?) -> Bool {
        //showing alert to user saying that printing is blocked
        self.showPrintingNotAllowedBlocker()
        completion?(Self.shared, false, nil)
        return false
    }

    ///  This function will display an alert saying that priting is blocked
    func showPrintingNotAllowedBlocker() {
        var keyWindow: UIWindow?
        ensureOnMainQueue {
            keyWindow = (UIApplication.shared as KeyWindowGettable).keyUIWindow
        }

        guard let rootViewController = keyWindow?.rootViewController else {
            return
        }
        let alertController = UIAlertController(title: "Warning",
                                                message: ControllerRestriction.uiPrintInteractionControllerRestricted.message,
                                                preferredStyle: .alert)
        alertController.addAction(UIAlertAction.init(title: "OK", style: .destructive))
        rootViewController.present(alertController, animated: true)
    }
}
