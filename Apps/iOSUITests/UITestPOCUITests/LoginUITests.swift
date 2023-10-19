//
//  LoginUITests.swift
//  UITestPOCUITests
//
//  Created by Ashish Awasthi on 16/10/23.
//

import XCTest

final class LoginUITests: BaseUITestcase {

    func testLogin() throws {
        StandaloneFlows.loginFlow(uiTestApp: self.uiTestApp)
        StandaloneFlows.logOutFlow(uiTestApp: self.uiTestApp)
    }
}


