//
//  SafariApplicationFlow.swift
//  UITestPOCUITests
//
//  Created by Ashish Awasthi on 19/01/24.
//


import XCTest

public class SafariBaseTestcase: XCTestCase{

    internal let safariUIApp: SafariUIApp = {
        return SafariUIApp()
    }()

    public lazy var application: XCUIApplication = safariUIApp.application
}

public class SafariUIApp: TestApplicationProtocol {

    public var application: XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
       return app
    }
    open lazy var safariScreen: SafariScreen = SafariScreen(application: self.application)
}

class SafariApplicationFlow {

    static func launchApplication(application: XCUIApplication)  {
        application.launch()
    }
}
