//
//  BaseUITest.swift
//  UITestPOCUITests
//
//  Created by Ashish Awasthi on 16/10/23.
//

import XCTest

//screen needs to know which app it belongs to
public protocol SDKScreenProtocol {

    var screenIdentifier: String { get }
    func waitForScreen(time: TimeInterval) -> Bool
    func waitForScreenToDisappear(time: TimeInterval) -> Bool
}

public extension SDKScreenProtocol {

    var screenIdentifier: String {
        "default"
    }
    func waitForScreenToDisappear(time: TimeInterval = 30) -> Bool {
        XCTFail("waitForScreenToDisappear(time: TimeInterval = 30) is not implemented by default. Needs to be implented by the class adopting this protocol")
        return false
    }
}

func describe(_ string: String, block: () -> Void) {
    XCTContext.runActivity(named: string) { _ in
        block()
    }
}

//app needs a bundle id
public protocol TestApplicationProtocol {
    //var bundleID: String {get}
    var application: XCUIApplication { get }
}

public extension TestApplicationProtocol {

    /// This API will launch an App without and environment variables.
    func launchApp() {
        self.application.launch()
        self.application.launchEnvironment.removeAll()
    }

    // Activate an application
    func activate() {
        self.application.activate()
    }

    /// This API will launch an app with Environment Variables passed. Post launch
    /// all environment variables will be destroyed.
    /// - Parameter options: [Key:Value] (String:String) for all launch Environment variables.
    func launchAppWithEnvOptions(options: [String: String]) {
        self.application.launchEnvironment = options
        self.launchApp()
    }
}

public class BaseUITestcase: XCTestCase{

    internal let uiTestApp: UITestApp = {
        return UITestApp()
    }()

    public lazy var application: XCUIApplication = uiTestApp.application
}

public class UITestApp: TestApplicationProtocol {

    public var application: XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["isRunningUITests"]
       return app
    }
    open lazy var homeScreen: HomeViewScreen = HomeViewScreen(application: self.application)
    open lazy var loginScreen: LoginViewScreen = LoginViewScreen(application: self.application)
    open lazy var productListScreen:ProductListViewScreen = ProductListViewScreen(application: self.application)
    open lazy var productDetailsScreen: ProductDetailsScreen = ProductDetailsScreen(application: self.application)
}
