//
//  BaseScreen.swift
//  UITestPOCUITests
//
//  Created by Ashish Awasthi on 17/10/23.
//

import XCTest
public enum HomeAction: Int {
    case login
    // MARK: Identifiers
    var identifier: String {
        switch self {
        case .login: return "loginButton"
        }
    }
}

public final class HomeViewScreen: SDKScreenProtocol {

    private var app: XCUIApplication
    static let screenId: String = "Home"
    private lazy var screenElement: XCUIElement = self.app.staticTexts[HomeViewScreen.screenId]

    // MARK: Action Elements
    private lazy var loginButton: XCUIElement = self.app.button(identifier: HomeAction.login.identifier)

    init(application: XCUIApplication) {
        self.app = application
    }

    public func waitForScreen(time: TimeInterval) -> Bool {
        return self.screenElement.waitForExistence(timeout: time)
    }

    public func actionONScreen(action: HomeAction) {
        switch action {
        case .login:
            self.loginButton.tap()
        }
    }
}
