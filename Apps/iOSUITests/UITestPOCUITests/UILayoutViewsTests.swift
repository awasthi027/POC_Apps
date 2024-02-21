//
//  UILayoutViewsTests.swift
//  UITestPOCUITests
//
//  Created by Ashish Awasthi on 22/01/24.
//

import XCTest

final class UILayoutViewsTests: BaseUITestcase {


    func testActionSheetActionClick()  {

        describe("Describe: Fresh Application Launch Flow") {
            UITestPOCFlows.launchApplication(application: uiTestApp.application)
            uiTestApp.homeScreen.waitForScreen(time: 1)
            uiTestApp.homeScreen.actionONScreen(action: .uiLayoutView)
            let typeText = "testText"
            let text = uiTestApp.uiLayoutViewsScreen.typeTextSelectTextCopyTextPasteTextAndReadText(typeText: typeText)
            XCTAssertEqual(text, typeText)
        }
    }

    func testSharePDFWithAvailableApp()  {

        describe("Describe: Fresh Application Launch Flow") {
            UITestPOCFlows.launchApplication(application: uiTestApp.application)
            uiTestApp.homeScreen.waitForScreen(time: 1)
            uiTestApp.homeScreen.actionONScreen(action: .uiLayoutView)
            uiTestApp.uiLayoutViewsScreen.actionONScreen(action: .sharePDF)
            uiTestApp.uiLayoutViewsScreen.waitForScreen(time: 1)
            let isSuccess = self.uiTestApp.uiLayoutViewsScreen.shareDocWith(app: "SITH SCL")
            XCTAssertTrue(isSuccess)
        }
    }
}
