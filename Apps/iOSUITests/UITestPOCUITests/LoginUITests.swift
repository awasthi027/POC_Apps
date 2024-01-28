//
//  LoginUITests.swift
//  UITestPOCUITests
//
//  Created by Ashish Awasthi on 16/10/23.
//

import XCTest

final class LoginUITests: BaseUITestcase {

    func testLogin() throws {
        UITestPOCFlows.loginFlow(uiTestApp: self.uiTestApp)
        UITestPOCFlows.logOutFlow(uiTestApp: self.uiTestApp)
    }
}


