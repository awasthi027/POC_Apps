//
//  UIPasteBoardTests.swift
//  UITestPOCUITests
//
//  Created by Ashish Awasthi on 19/01/24.
//

import XCTest

final class UIPasteBoardTests: BaseUITestcase {

    func testPasteBoardControll()  {
        describe("Describe: UIPaste Controll test case") {
            UITestPOCFlows.launchApplication(application: uiTestApp.application)
            uiTestApp.homeScreen.waitForScreen(time: 1)
            uiTestApp.homeScreen.actionONScreen(action: .uiLayoutView)
            uiTestApp.uiLayoutViewsScreen.copyAndPasteText()
        }
    }

   
}
