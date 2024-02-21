//
//  XCUIApplicationExtension.swift
//  UITestPOCUITests
//
//  Created by Ashish Awasthi on 17/10/23.
//

import Foundation
import XCTest

public enum ContextMenuOption {

    case selectall
    case select
    case copy
    case paste
    case cut

    var identifier: String {
        switch self {
        case .copy:         return "Copy"
        case .select:       return "Select"
        case .selectall:    return "Select All"
        case .paste:        return "Paste"
        case .cut:          return "Cut"
        }
    }

    static var tableIdentifier: String {
        return "ActivityListView"
    }
}

extension XCUIApplication {

    func button(identifier: String,
                timeout: TimeInterval = 2) -> XCUIElement {
        let element = self.buttons[identifier]
        XCTAssertTrue(element.waitForExistence(timeout: timeout))
        return element
    }

    func textFields(identifier: String,
                timeout: TimeInterval = 2) -> XCUIElement {
        let element = self.textFields[identifier]
        XCTAssertTrue(element.waitForExistence(timeout: timeout))
        return element
    }

    func secureTextField(identifier: String,
                timeout: TimeInterval = 2) -> XCUIElement {
        let element = self.secureTextFields[identifier]
        XCTAssertTrue(element.waitForExistence(timeout: timeout))
        return element
    }

    func textView(identifier: String,
                timeout: TimeInterval = 2) -> XCUIElement {
        let element = self.textViews[identifier]
        XCTAssertTrue(element.waitForExistence(timeout: timeout))
        return element
    }

    func tableView(identifier: String,
                timeout: TimeInterval = 2) -> XCUIElement {
        let pred = NSPredicate(format: "identifier == '\(identifier)'")
        let element = self.descendants(matching: .any).matching(pred).firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: timeout))
        return element
    }

    func navigationBackButton(identifier: String = "",
                              timeout: TimeInterval = 2) -> XCUIElement  {
        let element = self.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(element.waitForExistence(timeout: timeout))
        return element
    }

    func staticText(text: String,
                    timeout: TimeInterval = 2) -> XCUIElement {
        let element = self.staticTexts[text]
        XCTAssertTrue(element.waitForExistence(timeout: timeout))
        return element
    }

    func menuItem(identifier: String,
                  timeout: TimeInterval = 2) -> XCUIElement {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", identifier)
        let element = self.menuItems.containing(predicate).firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: timeout))
        return element
    }
}

extension XCUIElement {
    
    func listItem(identifier: String,
                  timeout: TimeInterval = 2) -> XCUIElement {
        let element = self.staticTexts[identifier].firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: timeout))
        return element
    }

    func clearAndTypeText(typeText: String) {
        self.tap() as Void
        //Clear any pre-existing text
        if let stringValue = self.value as? String {
            let deleteString = stringValue.map { _ in "\u{8}" }.joined(separator: "")
            self.typeText(deleteString)
        }
        self.typeText(typeText)
    }


    func longPress(timeInterval: TimeInterval = 2.0) {
        self.press(forDuration: timeInterval)
    }

    func tapIfExists() -> Bool {
        
        if self.exists {
            self.tap()
            return true
        }
        return false
    }
}
