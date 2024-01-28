//
//  TerminateAndRelaunchUITests.swift
//  UITestPOCUITests
//
//  Created by Ashish Awasthi on 12/01/24.
//

import Foundation

import XCTest



class TerminateAndRelaunchUITests: BaseUITestcase {

    static let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    class func deleteMyApp(name: String) {
        // Force delete the app from the springboard
        XCUIDevice.shared.press(.home)

        let icon = springboard.icons[name].firstMatch
        if icon.exists {
            let iconFrame = icon.frame
            let springboardFrame = springboard.frame
            icon.press(forDuration: 5)
            // Tap the little "X" button at approximately where it is. The X is not exposed directly
            springboard.coordinate(withNormalizedOffset: CGVector(dx: (iconFrame.minX + 3) / springboardFrame.maxX, dy: (iconFrame.minY + 3) / springboardFrame.maxY)).tap()

            let removeButtonApp = springboard.alerts.buttons["Delete App"]
            if removeButtonApp.waitForExistence(timeout: 2) {
                removeButtonApp.tap()
            }
            let deleteButton = springboard.alerts.buttons["Delete"]
            if deleteButton.waitForExistence(timeout: 2) {
                deleteButton.tap()
                springboard.tap()
            }
        }
    }

    func testApplicationTerminateAndRelaunch()  {
        UserDefaults.isUserLogin = false
        describe("Describe: Fresh Application Launch Flow") {
            UITestPOCFlows.launchApplication(application: uiTestApp.application)
            uiTestApp.homeScreen.waitForScreen(time: 2)
        }

        describe("Describe: Termination application") {
            UITestPOCFlows.terminate(application: uiTestApp.application)
        }

        describe("Describe: Launching application after Termination") {
            UITestPOCFlows.launchApplication(application: uiTestApp.application)
            uiTestApp.homeScreen.waitForScreen(time: 2)
        }
    }



}


