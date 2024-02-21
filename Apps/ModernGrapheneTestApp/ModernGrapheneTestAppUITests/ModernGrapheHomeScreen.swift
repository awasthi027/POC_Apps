//
//  ModernGrapheHomeScreen.swift
//  UITestPOCUITests
//
//  Created by Ashish Awasthi on 05/02/24.
//


import XCTest
public enum ModernGrapheHomeScreenAction: Int {
    case login
    case uiLayoutView
    // MARK: Identifiers
    var identifier: String {
        switch self {
        case .login: return "loginButton"
        case .uiLayoutView: return "uiLayoutActionButton"
        }
    }
}


public final class ModernGrapheHomeScreen: InitializableScreen {
    public var application: XCUIApplication

    public init<AppProvider>(_ appProviding: AppProvider) where AppProvider : AppProviding {
        self.application = appProviding.app
    }

    static let screenId: String = "Home"
    private lazy var screenElement: XCUIElement = self.app.staticTexts[ModernGrapheHomeScreen.screenId]

    // MARK: Action Elements
    private lazy var loginButton: XCUIElement = self.app.button(identifier: ModernGrapheHomeScreenAction.login.identifier)
    private lazy var uiLayoutViewButton: XCUIElement = self.app.button(identifier: ModernGrapheHomeScreenAction.uiLayoutView.identifier)

    @discardableResult  public func waitForScreen(time: TimeInterval) -> Bool {
        return self.screenElement.waitForExistence(timeout: time)
    }

    public func actionONScreen(action: ModernGrapheHomeScreenAction) {
        switch action {
        case .login:
            self.loginButton.tap()
        case .uiLayoutView:
            self.uiLayoutViewButton.tap()
        }
    }

//    @Feature(\.buttons["I Understand"], options: .skip)
//    var acknowledgeButton: Button

}

/* // Copy and Paste text in text field

 */
public protocol LabelBearing: FeatureBase{}
public extension LabelBearing {
    var label: String {
        self.element.label
    }

//    @Flow
//    func matches(_ text: String) -> Bool {
//        self.label == text
//    }
//
//    @Flow
//    func contains(_ subString: String) -> Bool {
//        self.label.contains(subString)
//    }
}
public protocol Tappable: FeatureBase {}
public extension Tappable {
    var isEnabled: Bool {
        self.element.isEnabled
    }

//    @Flow
//    var tap: Bool {
//        if self.validated {
//            self.element.tap(checkExistence: false)
//        }
//    }
//
//    // Tap if an element exists within a certain timeframe
//    @Flow
//    func tap(timeout: TimeInterval = 2.0) -> Bool {
//        if self.validate(timeout: timeout) {
//            self.tap
//        }
//    }
//
//    @Flow
//    var longPress: Bool {
//        if self.validated {
//            self.element.longPress(checkExistence: false)
//        }
//    }
//
//    @Flow
//    func longPress(_ forDuration: TimeInterval = 2.0) -> Bool {
//        if self.validated {
//            self.element.longPress(checkExistence: false, duration: forDuration)
//        }
//    }

}

public protocol Selectable: FeatureBase {}
public extension Selectable {
    var isSelected: Bool {
        self.element.isSelected
    }
}

open class Text: FeatureBase, LabelBearing {}
open class Button: Text, Tappable, Selectable {}
