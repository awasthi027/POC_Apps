//
//  XCUIApplicationExtension.swift
//  UITestPOCUITests
//
//  Created by Ashish Awasthi on 17/10/23.
//

import Foundation
import XCTest

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
}

extension XCUIElement {
    func listItem(identifier: String,
                  timeout: TimeInterval = 2) -> XCUIElement {
        let element = self.staticTexts[identifier].firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: timeout))
        return element
    }
}
