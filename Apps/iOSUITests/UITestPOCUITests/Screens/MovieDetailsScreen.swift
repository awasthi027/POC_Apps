//
//  MovieDetailsScreen.swift
//  UITestPOCUITests
//
//  Created by Ashish Awasthi on 18/10/23.
//

import XCTest
public enum MovieDetailsAction: Int {
    case back
    // MARK: Identifiers
    var identifier: String {
        switch self {
        case .back: return "back"
        }
    }
}

public final class MovieDetailsScreen: SDKScreenProtocol {

    private var app: XCUIApplication
    static let screenId: String = "Movie Details"
    private lazy var screenElement: XCUIElement = self.app.staticTexts[MovieDetailsScreen.screenId]

    // MARK: Action Elements
    private lazy var backButton: XCUIElement = self.app.navigationBackButton()

    init(application: XCUIApplication) {
        self.app = application
    }

    public func waitForScreen(time: TimeInterval) -> Bool {
        return self.screenElement.waitForExistence(timeout: time)
    }

    public func actionONScreen(action: MovieDetailsAction) {
        switch action {
        case .back:
            self.backButton.tap()
        }
    }
}
