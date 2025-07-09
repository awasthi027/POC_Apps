//
//  SafariAppTests.swift
//  UITestPOCUITests
//
//  Created by Ashish Awasthi on 19/01/24.
//


import XCTest

final class SafariAppTests: SafariBaseTestcase {

    let restrictionMessage: String = " The administrator doesn\'t allow this document to be opened in the selected app. - Google Search"

    /* 1. Launch Storyboard
     2. Type in storyboard search bar
     3. Select from search bar
     4. Copy from search bar
     5. Cleare from search bar
     6. Paste in Search bar
     7. Get text from search and compare with pasted text */

    func testApplicationPasteOptionWithSafari() {

        describe("Describe: Copy paste and read text") {
            SafariApplicationFlow.launchApplication(application: safariUIApp.application)
            safariUIApp.safariScreen.waitForScreen(time: 1.0)
            let typeText = "Ashish"
            XCTAssertEqual(safariUIApp.safariScreen.typeSelectCopyPasteReadText(typeText: typeText), typeText)
        }
    }

    func testReadAdminRestricationText() {
        describe("Describe: Copy paste and read text") {
            SafariApplicationFlow.launchApplication(application: safariUIApp.application)
            safariUIApp.safariScreen.waitForScreen(time: 1.0)
            XCTAssertEqual(safariUIApp.safariScreen.validateRestrictionText(), restrictionMessage)
        }
    }

    func testTypeTextSelectAllAndCopyText() {
        describe("Describe: Copy paste and read text") {
            SafariApplicationFlow.launchApplication(application: safariUIApp.application)
            safariUIApp.safariScreen.waitForScreen(time: 1.0)
            let text = "Ashish Awasthi"
            XCTAssertEqual(safariUIApp.safariScreen.typeTextSelectAllSameTextAndCopy(textToCopy: text), text)
        }
    }

    func testOtherAppExtension() {
        let extensionName = "SITH SCL Action"
        let validateExtensionScreenNavBar = "Content Extension"
        let url = "www.google.com"
        let app = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        app.launch()

        let searchBar: XCUIElement = app.textFields["Address"]
        let isRetrun: Bool = true
        searchBar.tap() as Void
        let enter = isRetrun ? "\n" : ""
        searchBar.typeText("\(url)\(enter)")

        wait(app: app, alertTitile: "WaitingforShareButton")

        let shareButton = app.toolbars.buttons["Share"]
        shareButton.tap() as Void


        var extensionButton = app.otherElements["ActivityListView"].collectionViews.buttons[extensionName]

        if extensionButton.exists == false {
            let activityListView: XCUIElement =  app.otherElements.element(matching: .other,
                                                                           identifier: "ActivityListView")
            extensionButton = activityListView.collectionViews.cells[extensionName]
            if extensionButton.exists == false {
                activityListView.scrollUp()
                extensionButton = activityListView.collectionViews.cells[extensionName]
            }
        }

        extensionButton.tap() as Void
         wait(app: app, timeOut: 8.0,alertTitile: "WaitingForExtension")
        let okButton = app.alerts.buttons["OK"]
        if okButton.exists{
            okButton.tap() as Void
        }
        let button = app.buttons["vmw.sdk.usermessagingscreen.usermessagingbutton"]
        if button.exists {
            button.tap() as Void
        }

        let dismiss = app.buttons["dismiss"]
        if dismiss.exists {
            dismiss.tap() as Void
        }
        let extensionNav = app.navigationBars[validateExtensionScreenNavBar]
        XCTAssertTrue(extensionNav.exists)

        let closeExtButton = app.buttons["CloseExtension"]
        if closeExtButton.exists {
            closeExtButton.tap() as Void
        }
    }

    func wait(app: XCUIApplication,
                                    timeOut: TimeInterval = 5.0,
                                          alertTitile: String = "NotExpectingAlertJustWaitingForScreen") {
        let alert = app.alerts[alertTitile]
        XCTAssertFalse(alert.waitForExistence(timeout: timeOut))
    }

    func testThisAppShareExtension() {
        let uiTestPOCAPP = XCUIApplication()
        uiTestPOCAPP.launch()
        wait(app: uiTestPOCAPP, alertTitile: "LaunchngUITestApp")
     
        let extensionName = "UITestPOC"
        let validateExtensionScreenNavBar = "Hello iOS Shared Extension"
        let url = "www.google.com"
        let app = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        app.launch()

        let searchBar: XCUIElement = app.textFields["Address"]
        let isRetrun: Bool = true
        searchBar.tap() as Void
        let enter = isRetrun ? "\n" : ""
        searchBar.typeText("\(url)\(enter)")

        wait(app: app, alertTitile: "WaitingforShareButton")

        let shareButton = app.toolbars.buttons["Share"]
        shareButton.tap() as Void

        var extensionButton = app.otherElements["ActivityListView"].collectionViews.buttons[extensionName]
        if extensionButton.exists == false {
            let activityListView: XCUIElement =  app.otherElements.element(matching: .other,
                                                                           identifier: "ActivityListView")
            extensionButton = activityListView.collectionViews.cells[extensionName]
            if extensionButton.exists == false {
                activityListView.scrollUp()
                extensionButton = activityListView.collectionViews.cells[extensionName]
            }
        }
        extensionButton.tap() as Void
        wait(app: app, timeOut: 8.0,alertTitile: "WaitingForExtension")

        let click = app.buttons["Click"]
        if click.exists {
            click.tap() as Void
        }
    }
}
