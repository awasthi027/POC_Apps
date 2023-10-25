//
//  productListViewScreen.swift
//  UITestPOCUITests
//
//  Created by Ashish Awasthi on 17/10/23.
//


import XCTest



public enum ProductListAction {
    case logout
    case tableView
    case tableItem(Int)
    // MARK: Identifiers
    var identifier: String {
        switch self {
        case .logout: return "logoutButton"
        case .tableView: return "productListView"
        case .tableItem(let itemIndex): return "product_item_\(itemIndex)"
        }
    }
}

public final class ProductListViewScreen: SDKScreenProtocol {

    private var app: XCUIApplication
    static let screenId: String = "Product List"
    private lazy var screenElement: XCUIElement = self.app.staticTexts[ProductListViewScreen.screenId]

    // MARK: Action Elements
    private lazy var logoutButton: XCUIElement = self.app.button(identifier: ProductListAction.logout.identifier)
    private lazy var tableView: XCUIElement = self.app.tableView(identifier: ProductListAction.tableView.identifier)


    init(application: XCUIApplication) {
        self.app = application
    }

    public func waitForScreen(time: TimeInterval) -> Bool {
        return self.screenElement.waitForExistence(timeout: time)
    }

    public func actionONScreen(action: ProductListAction) {
        switch action {
        case .logout:
            self.logoutButton.tap()
        case .tableView:
            self.logoutButton.tap()
        case .tableItem(let itemIndex):
            let cellItem = tableView.listItem(identifier: "product_item_\(itemIndex)")
            cellItem.tap()
        }
    }
}
