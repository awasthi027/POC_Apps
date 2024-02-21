//
//  ModernGrapheneTest.swift
//  UITestPOCUITests
//
//  Created by Ashish Awasthi on 05/02/24.
//


import XCTest

final class ModernGrapheneTest: BaseUITestcase {


    func testActionSheetActionClick()  {

        describe("Describe: Fresh Application Launch Flow") {
            UITestPOCFlows.launchApplication(application: modenGraphenApp.application)
            modenGraphenApp.homeScreen.waitForScreen(time: 1)
            modenGraphenApp.homeScreen.actionONScreen(action: .login)
        }
    }
}
