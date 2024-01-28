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
}
