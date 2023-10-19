//
//  MovieListUITests.swift
//  UITestPOCUITests
//
//  Created by Ashish Awasthi on 18/10/23.
//

import XCTest

final class MovieListUITests: BaseUITestcase {

    func testMovieDetails() throws {
        StandaloneFlows.loginFlow(uiTestApp: self.uiTestApp)
        StandaloneFlows.navigateOnMoviewDetials(uiTestApp: self.uiTestApp)
        StandaloneFlows.logOutFlow(uiTestApp: self.uiTestApp)
    }
}
