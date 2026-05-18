//
//  UnitTestUITests.swift
//  UnitTestUITests
//
//  Created by Ashish Awasthi on 14/05/26.
//

import XCTest

final class UnitTestUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["UITEST_IN_MEMORY_STORE"] = "1"
    }

    @MainActor
    func testSignUpHappyPathShowsHome() throws {
        app.launch()

        app.buttons["Sign Up"].tap()
        app.textFields[UIElementID.SignUp.firstNameField].tap()
        app.typeText("Jamie\n")
        app.typeText("Stone\n")
        app.typeText("jamie@example.com\n")
        app.typeText("jamie\n")
        app.typeText("Password123\n")
        app.typeText("Password123")
        app.buttons[UIElementID.SignUp.submitButton].tap()

        XCTAssertTrue(app.otherElements[UIElementID.Home.screen].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts[UIElementID.Home.welcomeLabel].label.contains("Jamie"))
    }

    @MainActor
    func testSignUpValidationShowsMismatchError() throws {
        app.launch()

        app.buttons["Sign Up"].tap()
        app.textFields[UIElementID.SignUp.firstNameField].tap()
        app.typeText("Jamie\n")
        app.typeText("Stone\n")
        app.typeText("jamie@example.com\n")
        app.typeText("jamie\n")
        app.typeText("Password123\n")
        app.typeText("Password321")
        app.buttons[UIElementID.SignUp.submitButton].tap()

        XCTAssertTrue(app.staticTexts[UIElementID.SignUp.errorLabel].waitForExistence(timeout: 2))
        XCTAssertEqual(
            app.staticTexts[UIElementID.SignUp.errorLabel].label,
            "Password and Confirm Password must match."
        )
    }

    @MainActor
    func testSignInUnknownUserRedirectsToSignUp() throws {
        app.launch()

        app.buttons["Sign In"].tap()
        app.textFields[UIElementID.SignIn.identifierField].tap()
        app.typeText("missinguser\n")
        app.typeText("Password123")
        app.buttons[UIElementID.SignIn.submitButton].tap()

        XCTAssertTrue(app.otherElements[UIElementID.SignUp.screen].waitForExistence(timeout: 2))
        XCTAssertEqual(app.textFields[UIElementID.SignUp.usernameField].value as? String, "missinguser")
    }

    @MainActor
    func testOfflineSignInWithSeededLocalUserShowsHome() throws {
        app.launchEnvironment["UITEST_SEED_LOCAL_USER"] = "1"
        app.launchEnvironment["UITEST_START_OFFLINE"] = "1"
        app.launch()

        app.buttons["Sign In"].tap()
        app.textFields[UIElementID.SignIn.identifierField].tap()
        app.typeText("demo\n")
        app.typeText("Password123")
        app.buttons[UIElementID.SignIn.submitButton].tap()

        XCTAssertTrue(app.otherElements[UIElementID.Home.screen].waitForExistence(timeout: 2))
    }
}

private enum UIElementID {
    enum SignIn {
        static let identifierField = "auth.signIn.identifierField"
        static let passwordField = "auth.signIn.passwordField"
        static let submitButton = "auth.signIn.submitButton"
    }

    enum SignUp {
        static let screen = "auth.signUp.screen"
        static let firstNameField = "auth.signUp.firstNameField"
        static let lastNameField = "auth.signUp.lastNameField"
        static let emailField = "auth.signUp.emailField"
        static let usernameField = "auth.signUp.usernameField"
        static let passwordField = "auth.signUp.passwordField"
        static let confirmPasswordField = "auth.signUp.confirmPasswordField"
        static let submitButton = "auth.signUp.submitButton"
        static let errorLabel = "auth.signUp.errorLabel"
    }

    enum Home {
        static let screen = "auth.home.screen"
        static let welcomeLabel = "auth.home.welcomeLabel"
    }
}
