//
//  LoginViewUITests.swift
//  UITestPOC
//
//  Created by Ashish Awasthi on 23/07/25.
//

import XCTest
import LearningSubspecSDK
import XCTestExtension

final class LoginViewUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        LoggingViewModel.shared.clearLogs()
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    func testLoginLogFileContainsSuccess() throws {
        let app = XCUIApplication()
        app.launch()

        let usernameTextField = app.textFields(identifier: "username.text.field")
        XCTAssertTrue(usernameTextField.tapIfExists())
        usernameTextField.clearAndTypeText(typeText: "testuser")

        let passwordTextField = app.secureTextField(identifier:"password.text.field")
        XCTAssertTrue(passwordTextField.tapIfExists())
        passwordTextField.clearAndTypeText(typeText: "password123")


        let loginButton = app.button(identifier: "login.button")
        XCTAssertTrue(loginButton.tapIfExists())

        // Wait for log to be written
        app.wait(timeOut: 1.0)

        // Use LogFileManager to verify log contains success
        let logSuccess = app.verifyLog(log: CheckInPoints.loginSuccess)
        XCTAssertTrue(logSuccess, "Log file should contain 'Login Successfully'")

        XCTAssertTrue(app.navigatioBarTextExist(text: "Home"))

        let logoutButton = app.button(identifier:"logout.button")
        XCTAssertTrue(logoutButton.tapIfExists())

        let logoutSuccess = app.verifyLog(log: CheckInPoints.userLoggedOut)
        XCTAssertTrue(logoutSuccess, "Log file should contain 'User has logged out'")

        XCTAssertTrue(app.navigatioBarTextExist(text: "Login"))
    }
}

protocol AutomationLogs {
    func verifyLog(log: String, count: Int) -> Bool
    func allLogs() -> [String]
}

extension XCUIApplication: AutomationLogs {

    func verifyLog(log: String, count: Int = 1) -> Bool {
        let logs = self.allLogs()
        return logs.contains(log)
    }

    func allLogs() -> [String] {
        let logElement = self.staticTexts[LoggingViewModel.shared.accessibilityIdentifier]
        XCTAssertTrue(logElement.waitForExistence(timeout: 5))
        let logContents = logElement.label
        return logContents.split(separator: LoggingViewModel.shared.separator).map(String.init)
    }
}
