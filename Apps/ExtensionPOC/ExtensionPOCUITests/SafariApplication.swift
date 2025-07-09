//
//  SafariApplication.swift
//  ExtensionPOC
//
//  Created by Ashish Awasthi on 04/07/25.
//

import XCTest

class SafariApplication {

    var app: XCUIApplication
    init() {
        app = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
    }

    func selectExtentioon(extensionName: String) -> Bool {
        let url = "www.google.com"
        app.launch()

        let searchBar: XCUIElement = app.textFields["Address"]
        let isRetrun: Bool = true
        searchBar.tap() as Void
        let enter = isRetrun ? "\n" : ""
        searchBar.typeText("\(url)\(enter)")
        app.wait(alertTitile: "WaitingforShareButton")

        let shareButton = app.toolbars.buttons["Share"]
        shareButton.tap() as Void

        app.wait(alertTitile: "WaitingForExtenOption")

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
        if extensionButton.exists {
            extensionButton.tap() as Void
        }
        app.wait(timeOut: 2.0,alertTitile: "WaitingOnExtensionScreen")
        return extensionButton.exists
    }
}
