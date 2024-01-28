//
//  SafariScreen.swift
//  UITestPOCUITests
//
//  Created by Ashish Awasthi on 19/01/24.
//

import Foundation
import XCTest

enum SafariAppAction: Int {
    case urlBarID
    case keyboardGoID
    case shareButtonID
    case safariLabel

    // MARK: Identifiers
    var identifier: String {
        switch self {
        case .urlBarID: return "Address"
        case .keyboardGoID: return "Go"
        case .shareButtonID: return "Share"
        case .safariLabel: return "Safari"
        }
    }
}
public final class SafariScreen: SDKScreenProtocol {

    private var app: XCUIApplication
    static let screenId: String = "Safari Screen"
    private lazy var screenElement: XCUIElement = self.app.staticTexts[HomeViewScreen.screenId]



    // MARK: Action Elements

    private lazy var urlBar: XCUIElement = self.app.otherElements[SafariAppAction.urlBarID.identifier]
    private lazy var safariAppLabel: Bool = self.app.label.elementsEqual(SafariAppAction.safariLabel.identifier)
    private lazy var searchTextField: XCUIElement = self.app.textFields[SafariAppAction.urlBarID.identifier]
    private lazy var keyboardGoButton: XCUIElement = self.app.keyboards.firstMatch.buttons[SafariAppAction.keyboardGoID.identifier]
    private lazy var shareButton: XCUIElement = self.app.toolbars.buttons[SafariAppAction.shareButtonID.identifier]

    @discardableResult  public func waitForScreen(time: TimeInterval) -> Bool {
        return self.screenElement.waitForExistence(timeout: time)
    }

    init(application: XCUIApplication) {
        self.app = application
    }


    func typeSelectCopyPasteReadText(typeText: String) -> String {
        self.searchTextField.tap()
        self.searchTextField.clearAndTypeText(typeText: typeText)

        self.searchTextField.longPress()
        let selectElement = self.app.menuItem(identifier: ContextMenuOption.select.identifier)
        selectElement.tap()


        let copyElement = self.app.menuItem(identifier: ContextMenuOption.copy.identifier)
        copyElement.tap()

        // Wait to clear complete text
        self.searchTextField.tap()
        self.searchTextField.clearAndTypeText(typeText: "")
        XCTAssertTrue(self.searchTextField.waitForExistence(timeout: 3))

        self.searchTextField.longPress()
        let pasteElement = self.app.menuItem(identifier: ContextMenuOption.paste.identifier)
        pasteElement.tap()

        //The only way I am able to retrieve URL Bar value in Safari App
        let result = self.searchTextField.value as? String
        return result ?? ""
    }

    func validateRestrictionText(textToCopy: String = "sampleText") -> String {
        self.searchTextField.tap()
        self.searchTextField.clearAndTypeText(typeText: textToCopy)
        XCTAssertTrue(self.searchTextField.waitForExistence(timeout: 2), "Waiting for search bar timed out")

        self.searchTextField.doubleTap()
        let copyElement = self.app.menuItem(identifier: ContextMenuOption.copy.identifier)
        copyElement.tap()

        // Wait to clear complete text
        self.searchTextField.tap()
        self.searchTextField.clearAndTypeText(typeText: "")
        XCTAssertTrue(self.searchTextField.waitForExistence(timeout: 2))

        self.searchTextField.longPress()
        let pasteElement = self.app.menuItem(identifier: ContextMenuOption.paste.identifier)
        pasteElement.tap()

        //The only way I am able to retrieve URL Bar value in Safari App
        let result = self.searchTextField.value as? String
        return result ?? ""
    }
}

