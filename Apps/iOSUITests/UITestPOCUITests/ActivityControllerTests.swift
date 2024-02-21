//
//  ActivityControllerTests.swift
//  UITestPOCUITests
//
//  Created by Ashish Awasthi on 19/01/24.
//

import XCTest

final class ActivityControllerTests: BaseUITestcase {

    func testShareActivityViewController()  {
        UserDefaults.isUserLogin = false
        describe("Describe: Fresh Application Launch Flow") {
            UITestPOCFlows.launchApplication(application: uiTestApp.application)
            uiTestApp.homeScreen.waitForScreen(time: 1)
            uiTestApp.homeScreen.actionONScreen(action: .uiLayoutView)

            self.uiTestApp.uiLayoutViewsScreen.actionONScreen(action: .sharePDF)
           // self.uiTestApp.homeScreen.actionONScreen(action: .searchTextField)
        }
    }
}
