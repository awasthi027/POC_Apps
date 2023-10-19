//
//  LoginViewScreen.swift
//  UITestPOCUITests
//
//  Created by Ashish Awasthi on 17/10/23.
//

import XCTest

public enum LoginAction: Int {
    case enterUserName
    case enterPassword
    case requestLogin
    // MARK: Identifiers
    var identifier: String {
        switch self {
        case .enterUserName: return "usernameInputField"
        case .enterPassword: return "passwordInputField"
        case .requestLogin: return "loginRequestButton"
        }
    }
}

public final class LoginViewScreen: SDKScreenProtocol {

    private var app: XCUIApplication
    static let screenId: String = "Login"
    private lazy var screenElement: XCUIElement = self.app.staticTexts[LoginViewScreen.screenId]

    // MARK: Identifiers
    private static let requestLoginButton     = "loginRequestButton"
    private static let userNameTextField      = "usernameInputField"
    private static let passwordTextField      = "passwordInputField"

    // MARK: Action Elements
    private lazy var userNameTextField: XCUIElement = self.app.textFields(identifier: LoginAction.enterUserName.identifier)
    private lazy var passwordTextField: XCUIElement = self.app.secureTextField(identifier: LoginAction.enterPassword.identifier)
    private lazy var requestLoginButton: XCUIElement = self.app.button(identifier: LoginAction.requestLogin.identifier)


    init(application: XCUIApplication) {
        self.app = application
    }

    public func waitForScreen(time: TimeInterval) -> Bool {
        return self.screenElement.waitForExistence(timeout: time)
    }

    public func invokeLoginFlow() {
        XCTAssertFalse(requestLoginButton.isEnabled)
        self.actionONScreen(action: .enterUserName)
        self.actionONScreen(action: .enterPassword)
        XCTAssertTrue(requestLoginButton.isEnabled)
        self.actionONScreen(action: .requestLogin)
    }

    public func actionONScreen(action: LoginAction) {
        switch action {
        case .enterUserName:
            self.userNameTextField.tap()
            self.userNameTextField.typeText("ashishawasthi")
        case .enterPassword:
            self.passwordTextField.tap()
            self.passwordTextField.typeText("thisisnotapassword")
        case .requestLogin:
            self.requestLoginButton.tap()
        }
    }
}
