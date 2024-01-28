//
//  BaseScreen.swift
//  UITestPOCUITests
//
//  Created by Ashish Awasthi on 17/10/23.
//

import XCTest
public enum HomeAction: Int {
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


public final class HomeViewScreen: SDKScreenProtocol {

    private var app: XCUIApplication
    static let screenId: String = "Home"
    private lazy var screenElement: XCUIElement = self.app.staticTexts[HomeViewScreen.screenId]

    // MARK: Action Elements
    private lazy var loginButton: XCUIElement = self.app.button(identifier: HomeAction.login.identifier)
    private lazy var uiLayoutViewButton: XCUIElement = self.app.button(identifier: HomeAction.uiLayoutView.identifier)

    init(application: XCUIApplication) {
        self.app = application
    }

    @discardableResult  public func waitForScreen(time: TimeInterval) -> Bool {
        return self.screenElement.waitForExistence(timeout: time)
    }

    public func actionONScreen(action: HomeAction) {
        switch action {
        case .login:
            self.loginButton.tap()
        case .uiLayoutView:
            self.uiLayoutViewButton.tap()
        }
    }


}

/* // Copy and Paste text in text field

 */

