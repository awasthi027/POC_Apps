//
//  ProductListUITests.swift
//  UITestPOCUITests
//
//  Created by Ashish Awasthi on 18/10/23.
//

import XCTest

final class ProductListUITests: BaseUITestcase {

    func testProductDetails() throws {
        UITestPOCFlows.loginFlow(uiTestApp: self.uiTestApp)
        UITestPOCFlows.navigateOnProductDetials(uiTestApp: self.uiTestApp)
        UITestPOCFlows.logOutFlow(uiTestApp: self.uiTestApp)
    }


    func testProductDetailsClickMe() throws {
        UITestPOCFlows.loginFlow(uiTestApp: self.uiTestApp)
        UITestPOCFlows.navigateOnProductDetialsClickMe(uiTestApp: self.uiTestApp)
        UITestPOCFlows.logOutFlow(uiTestApp: self.uiTestApp)
    }
}
