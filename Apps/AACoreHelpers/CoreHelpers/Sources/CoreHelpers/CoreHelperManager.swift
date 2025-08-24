//
//  ApplicationManager.swift
//  CoreHelpers
//
//  Created by Ashish Awasthi on 12/08/25.
//
import UIKit
import Foundation

enum ControllerRestriction {
    case uiPrintInteractionControllerRestricted
    case uiDocumentInteractionControllerRestricted
    case uiActivityControllerRestricted
    var message: String {
        switch self {
        case .uiPrintInteractionControllerRestricted:
            return "As per your corporate policy printing is restricted on this device"
        case .uiDocumentInteractionControllerRestricted:
            return "The administrator doesn't allow this document to be opened in the selected app."
        case .uiActivityControllerRestricted:
            return "The administrator doesn't allow this document to be opened in the selected app."
        }
    }
}
open class CoreHelperManager {

    public static let shared = CoreHelperManager()
    private init() { }
    // this entry should be read from plist, swizzle method getting called before app lannched
    internal var isEnabled: Bool = true
    internal var isWritingToolsAllowed: Bool = true
    internal var isCopyOutAllowed : Bool = true
    internal var isPasteInsideAllowed: Bool = true
    /// If set to ture, it will restrict share sheet from activity controller, default value is True
    /// Note: UIDocInteractionController and UIActivityControlller is not allowed together on either one we can apply restriction at a time
    internal var isRestrictionOnActivityController: Bool = true
    /// If set to ture, it will restrict share sheet from UIDocInteractionController, default value is False
    /// Note: UIDocInteractionController and UIActivityControlller is not allowed together on either one we can apply restriction at a time
    /// UIDocInteractionController Internally uses UIActivityControlller if present as presentOpenInMenu In that case only UIActivityControlller restriction will be applied
    internal var isRestrictionOnUIDocInteractionController: Bool = false
    /// if isRestrictionOnUIDocInteractionController is true then only document shared with allowed apps
    internal var documentShareAllowedWithApps: [String] = []
    /// If set to true, it will restrict print interaction controller UI, default value is TRUE
    internal var isRestrictionUIPrintInteractionController: Bool = true

    internal var isPrintingAllowed: Bool = true

    public func config(writingToolsAllowed: Bool = true,
                       copyPasteOutsideAllowed: Bool = true,
                       pasteInSideAllowed: Bool = true,
                       restrictionOnActivityController: Bool = true,
                       restrictionOnUIDocInteractionController: Bool = false,
                       restrictionUIPrintInteractionController: Bool = true,
                       printingAllowed: Bool = true) {
        self.isWritingToolsAllowed = writingToolsAllowed
        self.isCopyOutAllowed  = copyPasteOutsideAllowed
        self.isPasteInsideAllowed = pasteInSideAllowed
        self.isRestrictionOnActivityController = restrictionOnActivityController
        self.isRestrictionOnUIDocInteractionController = restrictionOnUIDocInteractionController
        self.isRestrictionUIPrintInteractionController = restrictionUIPrintInteractionController
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
