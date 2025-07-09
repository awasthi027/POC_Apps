//
//  UITestExtensions.swift
//  ExtensionPOC
//
//  Created by Ashish Awasthi on 01/07/25.
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


public extension XCUIElement {
    func visible() -> Bool {
        guard self.exists && !self.frame.isEmpty && self.isHittable else {
            return false
        }
        return XCUIApplication().windows.element(boundBy: 0).frame.contains(self.frame)
    }

#if !targetEnvironment(macCatalyst)
    /// Send a specific type of tap to an element
    /// - Parameters:
    /// - numberOfTaps: the amount of times to tap an element
    /// - numberOfTouches: the amount of points(fingers) to touch an element with
    func tapElement(numberOfTaps: Int, numberOfTouches: Int) {
        self.tap(withNumberOfTaps: numberOfTaps, numberOfTouches: numberOfTouches) as Void
    }
#endif

    // Scroll up an element
    func scrollUpToElement(element: XCUIElement) {
        while !element.visible() {
            swipeUp() as Void
        }
    }

    // Scroll down an element
    func scrollDownToElement(element: XCUIElement) {
        while !element.visible() {
            swipeDown() as Void
        }
    }

    func scrollUp() {
        if self.isElementHittable {
            self.swipeUp() as Void
        }
    }

    func scrollDown() {
        if self.isElementHittable {
            self.swipeDown() as Void
        }
    }
    /// Helper method to check if the XCUIElement is visible and hittable
    var isElementHittable: Bool {
        self.isVisible && self.isHittable
    }
    @objc
    var isVisible: Bool {
        exists && isHittable
    }
}

extension XCUIApplication {

    func wait(timeOut: TimeInterval = 5.0,
              alertTitile: String = "NotExpectingAlertJustWaitingForScreen") {
        let alert = self.alerts[alertTitile]
        XCTAssertFalse(alert.waitForExistence(timeout: timeOut))
    }
}
