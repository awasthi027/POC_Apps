//
// ProductDetailsScreen.swift
//  UITestPOCUITests
//
//  Created by Ashish Awasthi on 18/10/23.
//

import XCTest
public enum ProductDetailsAction: Int {
    case back
    case clickMe
    case okButton
    case cancelButton
    case userActionText
    // MARK: Identifiers
    var identifier: String {
        switch self {
        case .back: return "back"
        case .clickMe: return "clickMeButton"
        case .okButton: return "okButton"
        case .cancelButton: return "cancelButton"
        case .userActionText: return "userActionTextField"
        }
    }
}

public final class ProductDetailsScreen: SDKScreenProtocol {

    private var app: XCUIApplication
    static let screenId: String = "Product Details"
    private lazy var screenElement: XCUIElement = self.app.staticTexts[ProductDetailsScreen.screenId]

    // MARK: Action Elements
    private lazy var backButton: XCUIElement = self.app.navigationBackButton()
    private lazy var clickMeButton: XCUIElement = self.app.button(identifier: ProductDetailsAction.clickMe.identifier)
    private lazy var okButton: XCUIElement = self.app.button(identifier: ProductDetailsAction.okButton.identifier)
    private lazy var cancelButton: XCUIElement = self.app.button(identifier: ProductDetailsAction.cancelButton.identifier)


    init(application: XCUIApplication) {
        self.app = application
    }

    public func waitForScreen(time: TimeInterval) -> Bool {
        return self.screenElement.waitForExistence(timeout: time)
    }

    public func actionONScreen(action: ProductDetailsAction) {
        switch action {
        case .back:
            self.backButton.tap()
        case .clickMe:
            self.clickMeButton.tap()
        case .okButton:
            self.okButton.tap()
        case .cancelButton:
            self.cancelButton.tap()
        case .userActionText:
            let element = self.app.staticText(text: "User took action")
            XCTAssertEqual(element.label, "User took action")
            debugPrint("element: \(String(describing:element.label))")
        }
    }
}
