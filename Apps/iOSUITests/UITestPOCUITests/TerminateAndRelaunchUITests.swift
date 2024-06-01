//
//  TerminateAndRelaunchUITests.swift
//  UITestPOCUITests
//
//  Created by Ashish Awasthi on 12/01/24.
//

import Foundation

import XCTest


import XCTest


class SpringBoardManager{

let springBoardBundleId: String = "com.apple.springboard"
var springBoardApp: XCUIApplication
var appName: String
var timeout : Double = 3

//Identifiers for springboard search
let appSearchField: String = "dewey-search-field"
let deleteApp: String = "Delete App"
let delete: String = "Delete"
let cancel: String = "Cancel"

init(appName: String){
    self.appName = appName
    self.springBoardApp = XCUIApplication(bundleIdentifier: springBoardBundleId)
}

//Activate the springboard app and navigate to App library
func navigateToAppLibrary() -> Self{
        springBoardApp.activate()
        var isPresent = springBoardApp.searchFields[appSearchField].waitForExistence(timeout: timeout)
        while !isPresent{
            springBoardApp.swipeLeft()
            isPresent = springBoardApp.searchFields[appSearchField].waitForExistence(timeout: timeout)
        }

        return self
    }

//Search for the app in library
func searchForAppInLibrary() -> Self{
       let isPresent = springBoardApp.searchFields[appSearchField].waitForExistence(timeout: timeout)

        if isPresent{
            springBoardApp.searchFields[appSearchField].tap()
            springBoardApp.searchFields[appSearchField].typeText(appName)
        }
        return self
    }

//Long press to open delete option
 func tapToDeleteOption() -> Self{
        let identifierPredicate = NSPredicate(format: "identifier == %@", appName)
        let epiIcons = springBoardApp.descendants(matching: .icon).matching(identifierPredicate)
        let hittableEpiIcon = epiIcons.allElementsBoundByIndex.filter{$0.isHittable}.first
        hittableEpiIcon?.press(forDuration: 1)
        return self
    }

//Confirm delete operation and quit App library
func confirmDeleteApp(){
        let isPresent = springBoardApp.buttons[deleteApp].waitForExistence(timeout: timeout)
        if isPresent{
            springBoardApp.buttons[deleteApp].tap()
            springBoardApp.alerts.buttons[delete].tap()
            springBoardApp.staticTexts[cancel].waitForExistence(timeout: timeout)
            springBoardApp.staticTexts[cancel].tap()
        }
    }
}

class TerminateAndRelaunchUITests: BaseUITestcase {

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

    func testDeleteApp() {
        SpringBoardManager(appName: "<YOUR_APP_NAME_TO_BE_DELETED>")
        .navigateToAppLibrary()
        .searchForAppInLibrary()
        .tapToDeleteOption()
        .confirmDeleteApp()
    }
}


