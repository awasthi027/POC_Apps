//
//  ExtensionPOCUITests.swift
//  ExtensionPOCUITests
//
//  Created by Ashish Awasthi on 29/06/25.
//

import XCTest

final class ExtensionPOCUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }



    func testFeatureFlagWorkingFromExtension() {
        let uiTestPOCAPP = XCUIApplication()
        uiTestPOCAPP.launch()
        uiTestPOCAPP.wait(alertTitile: "LaunchngUITestApp")
        let safariApp = SafariApplication()
        XCTAssert(safariApp.selectExtentioon(extensionName: "ExtensionPOC"))
        safariApp.app.wait(timeOut: 2.0)
        let text = safariApp.app.staticTexts["IntructionLabel"].label
        XCTAssertEqual(text, "viewDidLoad\nSDK Name: Learning Subspec SDK\nSDK Version:1.0.0")
        let doneButton = safariApp.app.buttons["Done"]
        if doneButton.exists {
            doneButton.tap() as Void
        }
    }

    func testThisAppShareExtension() {

        let extensionTitle = "Share Extension"
        let uiTestPOCAPP = XCUIApplication()
        uiTestPOCAPP.launch()
        uiTestPOCAPP.wait(alertTitile: "LaunchngUITestApp")

        let safariApp = SafariApplication()
        XCTAssert(safariApp.selectExtentioon(extensionName: "ExtensionPOC"))
        safariApp.app.wait(timeOut: 1.0)
        XCTAssertTrue(safariApp.app.navigationBars[extensionTitle].exists)
        let doneButton = safariApp.app.buttons["Done"]
        if doneButton.exists {
            doneButton.tap() as Void
        }

    }

    func testSITHSCLShareExtension() {
        let extensionTitle = "Content Extension"
        // This app must be install in Simulator or device
        let uiTestPOCAPP = XCUIApplication(bundleIdentifier: "com.air-watch.content.locker")
        uiTestPOCAPP.launch()
        uiTestPOCAPP.wait(alertTitile: "LaunchngUITestApp")

        let safariApp = SafariApplication()
        XCTAssert(safariApp.selectExtentioon(extensionName: "SITH SCL Action"))
        safariApp.app.wait(timeOut: 1.0)
        let disMissButton = safariApp.app.buttons["Dismiss"]
        if disMissButton.exists {
            disMissButton.tap() as Void
        }
        XCTAssertTrue(safariApp.app.navigationBars[extensionTitle].exists)
        let doneButton = safariApp.app.buttons["Done"]
        if doneButton.exists {
            doneButton.tap() as Void
        }
    }

    func testLoginFlowFromExtension() {
        let extensionTitle = "Share Extension"
        let uiTestPOCAPP = XCUIApplication()
        uiTestPOCAPP.launch()
        uiTestPOCAPP.wait(alertTitile: "LaunchngUITestApp")

        let safariApp = SafariApplication()
        XCTAssert(safariApp.selectExtentioon(extensionName: "ExtensionPOC"))
        XCTAssertTrue(safariApp.app.navigationBars[extensionTitle].exists)

        let clickButton = safariApp.app.buttons["Click"]
        clickButton.tap() as Void

        safariApp.app.wait(timeOut: 5.0)
        let disMissButton = safariApp.app.buttons["Dismiss"]
        disMissButton.tap() as Void

        safariApp.app.wait(timeOut: 2.0)
        let doneButton = safariApp.app.buttons["Done"]
        doneButton.tap() as Void
    }
}
