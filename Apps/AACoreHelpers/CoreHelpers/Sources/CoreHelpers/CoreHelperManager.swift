//
//  ApplicationManager.swift
//  CoreHelpers
//
//  Created by Ashish Awasthi on 12/08/25.
//
import UIKit
import Foundation

open class CoreHelperManager {

    public static let shared = CoreHelperManager()
    private init() { }
    // this entry should be read from plist, swizzle method getting called before app lannched
    internal var isEnabled: Bool = true
    internal var isWritingToolsAllowed: Bool = true
    internal var isCopyOutAllowed : Bool = true
    internal var isPasteInsideAllowed: Bool = true
    internal var isActivityControllerAllowed: Bool = true
    internal var isPrintingAllowed: Bool = true

    public func config(writingToolsAllowed: Bool = true,
                       copyPasteOutsideAllowed: Bool = true,
                       pasteInSideAllowed: Bool = true,
                       activityControllerAllowed: Bool = true,
                       printingAllowed: Bool = true) {
        self.isWritingToolsAllowed = writingToolsAllowed
        self.isCopyOutAllowed  = copyPasteOutsideAllowed
        self.isPasteInsideAllowed = pasteInSideAllowed
        self.isActivityControllerAllowed = activityControllerAllowed
        self.isPrintingAllowed = printingAllowed
    }
    /// The actions list that are supported if `isEnabled` is true
    private lazy var supportedActions: [Selector] = {
        var allSupportedActions = [
            #selector(UIResponderStandardEditActions.cut(_:)),
            #selector(UIResponderStandardEditActions.copy(_:)),
            #selector(UIResponderStandardEditActions.paste(_:)),
            #selector(UIResponderStandardEditActions.select(_:)),
            #selector(UIResponderStandardEditActions.selectAll(_:)),
            #selector(UIResponderStandardEditActions.delete(_:)),
            #selector(UIResponderStandardEditActions.makeTextWritingDirectionLeftToRight(_:)),
            #selector(UIResponderStandardEditActions.makeTextWritingDirectionRightToLeft(_:)),
            #selector(UIResponderStandardEditActions.toggleBoldface(_:)),
            #selector(UIResponderStandardEditActions.toggleItalics(_:)),
            #selector(UIResponderStandardEditActions.toggleUnderline(_:)),
            #selector(UIResponderStandardEditActions.increaseSize(_:)),
            #selector(UIResponderStandardEditActions.decreaseSize(_:)),
            // Add add selector "_showTextStyleOptions(_:)" to allow `Bold`, `Italics`, and `Underline` actions
            Selector(stringLiteral: "_" + "show" + "TextStyle" + "Options:"),
            // Add add selector "_promptForReplace(_:)" and "replace(_:)" to allow `Replace...` action
            Selector(stringLiteral: "_" + "prompt" + "For" + "Replace:"),
            Selector(stringLiteral: "promptForReplace" + ":"),
            // Add add selector "_pspdf_findFirstResponder:" to allow `pspdf text field` action
            Selector(stringLiteral: "_" + "pspdf" + "_" + "findFirstResponder:")
        ]

        if #available(iOS 16.0, *) {
            // Add selector "_define:" to allow `lookup` and `search web` action
            allSupportedActions.append(Selector(stringLiteral: "_" + "define:"))
        }

#if swift(>=5.9)
        if  #available(iOS 17.0, *) {
            // Add selector "captureTextFromCamera:" to allow `scan text` action
            allSupportedActions.append(#selector(UIResponder.captureTextFromCamera(_:)))
        }
#endif
        return allSupportedActions
    }()
    /// Check if the action is supported or not
    ///
    /// - Parameter action: an Objective-C method selector
    /// - Returns: a boolean value indicates whether the passed in selector is supported
    func supports(action: Selector) -> Bool {
        return self.supportedActions.contains(action)
    }
}
