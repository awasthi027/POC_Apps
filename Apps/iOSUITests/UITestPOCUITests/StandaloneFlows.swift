//
//  StandaloneFlows.swift
//  UITestPOCUITests
//
//  Created by Ashish Awasthi on 17/10/23.
//

import Foundation
import XCTest

class StandaloneFlows {

    static func launchApplication(application: XCUIApplication ) {
        application.launch()
    }

    static func loginFlow(uiTestApp: UITestApp) {
        UserDefaults.isUserLogin = false
        StandaloneFlows.launchApplication(application: uiTestApp.application)
        describe("Launch Home Screen") {
            uiTestApp.homeScreen.actionONScreen(action: .login)
        }
        describe("Doing login..") {
            uiTestApp.loginScreen.invokeLoginFlow()
        }
    }

    static func logOutFlow(uiTestApp: UITestApp) {
        describe("Doing logout and clearnig data..") {
            uiTestApp.movieListScreen.actionONScreen(action: .logout)
            XCTAssertFalse(UserDefaults.isUserLogin)
            XCTAssertTrue(uiTestApp.application.navigationBars.staticTexts["Home"].exists)
        }
    }

    static func navigateOnMoviewDetials(uiTestApp: UITestApp) {
        describe("Exploring movie list and details...") {
            uiTestApp.movieListScreen.actionONScreen(action: .tableItem(5))
            XCTAssertTrue(uiTestApp.application.navigationBars.staticTexts["Movie Details"].exists)
            uiTestApp.movieDetailsScreen.actionONScreen(action: .back)

        }
    }
}
