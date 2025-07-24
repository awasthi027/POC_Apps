//
//  XCUIApplication.swift
//  XCTestExtension
//
//  Created by Ashish Awasthi on 24/07/25.
//

import XCTest

public extension XCUIApplication {

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

    func navigatioBarTextExist(text: String,
                              timeout: TimeInterval = 2) ->Bool  {
        let element = self.navigationBars.staticTexts[text]
        XCTAssertTrue(element.waitForExistence(timeout: timeout))
        return element.exists
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

public extension XCUIElement {

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


public extension XCUIApplication {

    func wait(timeOut: TimeInterval = 5.0,
              alertTitile: String = "NotExpectingAlertJustWaitingForScreen") {
        let alert = self.alerts[alertTitile]
        XCTAssertFalse(alert.waitForExistence(timeout: timeOut))
    }
}
