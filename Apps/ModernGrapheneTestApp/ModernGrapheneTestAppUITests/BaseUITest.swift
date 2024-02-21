//
//  BaseUITest.swift
//  ModernGrapheneTestAppUITests
//
//  Created by Ashish Awasthi on 06/02/24.
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

    public lazy var application: XCUIApplication = modenGraphenApp.application

    internal let modenGraphenApp: ModernGrapheneApp = {
        return ModernGrapheneApp(schemeName: "")
    }()

}

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
}
