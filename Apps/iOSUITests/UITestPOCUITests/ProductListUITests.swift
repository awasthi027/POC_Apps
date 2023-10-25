//
//  ProductListUITests.swift
//  UITestPOCUITests
//
//  Created by Ashish Awasthi on 18/10/23.
//

import XCTest

final class ProductListUITests: BaseUITestcase {

    func testProductDetails() throws {
        StandaloneFlows.loginFlow(uiTestApp: self.uiTestApp)
        StandaloneFlows.navigateOnProductDetials(uiTestApp: self.uiTestApp)
        StandaloneFlows.logOutFlow(uiTestApp: self.uiTestApp)
    }


    func testProductDetailsClickMe() throws {
        StandaloneFlows.loginFlow(uiTestApp: self.uiTestApp)
        StandaloneFlows.navigateOnProductDetialsClickMe(uiTestApp: self.uiTestApp)
        StandaloneFlows.logOutFlow(uiTestApp: self.uiTestApp)
    }
}
