//
//  XCUIElementExtension.swift
//  XCTestExtension
//
//  Created by Ashish Awasthi on 24/07/25.
//

import XCTest

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
