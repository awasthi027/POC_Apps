//
//  StandaloneFlows.swift
//  UITestPOCUITests
//
//  Created by Ashish Awasthi on 17/10/23.
//

import Foundation
import XCTest

class UITestPOCFlows {

    static func launchApplication(application: XCUIApplication ) {
        application.launch()
    }
    
    static func terminate(application: XCUIApplication ) {
        describe("Describe: Pressing Home") {
            XCUIDevice.shared.press(.home)
        }
        application.terminate()
    }

    static func loginFlow(uiTestApp: UITestApp) {
        UserDefaults.isUserLogin = false
        UITestPOCFlows.launchApplication(application: uiTestApp.application)
        describe("Launch Home Screen") {
            uiTestApp.homeScreen.actionONScreen(action: .login)
        }
        describe("Doing login..") {
            uiTestApp.loginScreen.invokeLoginFlow()
        }
    }

    static func logOutFlow(uiTestApp: UITestApp) {
        describe("Doing logout and clearnig data..") {
            uiTestApp.productListScreen.actionONScreen(action: .logout)
            XCTAssertFalse(UserDefaults.isUserLogin)
            XCTAssertTrue(uiTestApp.application.navigationBars.staticTexts["Home"].exists)
        }
    }

    static func navigateOnProductDetials(uiTestApp: UITestApp) {
        describe("Exploring product list and details...") {
            uiTestApp.productListScreen.actionONScreen(action: .tableItem(5))
            XCTAssertTrue(uiTestApp.application.navigationBars.staticTexts["Product Details"].exists)
            let _ = uiTestApp.productDetailsScreen.actionONScreen(action: .back)//User took action
        }
    }

    static func navigateOnProductDetialsClickMe(uiTestApp: UITestApp) {
        describe("Exploring product list and details...") {
            uiTestApp.productListScreen.actionONScreen(action: .tableItem(5))
            XCTAssertTrue(uiTestApp.application.navigationBars.staticTexts["Product Details"].exists)
            uiTestApp.productDetailsScreen.actionONScreen(action: .clickMe)
            uiTestApp.productDetailsScreen.actionONScreen(action: .okButton)
            uiTestApp.productDetailsScreen.actionONScreen(action: .userActionText)
            uiTestApp.productDetailsScreen.actionONScreen(action: .back)
        }
    }
}
