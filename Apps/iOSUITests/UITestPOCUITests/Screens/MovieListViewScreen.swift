//
//  MovieListViewScreen.swift
//  UITestPOCUITests
//
//  Created by Ashish Awasthi on 17/10/23.
//


import XCTest



public enum MovieListAction {
    case logout
    case tableView
    case tableItem(Int)
    // MARK: Identifiers
    var identifier: String {
        switch self {
        case .logout: return "logoutButton"
        case .tableView: return "movieListView"
        case .tableItem(let itemIndex): return "movie_item_\(itemIndex)"
        }
    }
}

public final class MovieListViewScreen: SDKScreenProtocol {

    private var app: XCUIApplication
    static let screenId: String = "Movie List"
    private lazy var screenElement: XCUIElement = self.app.staticTexts[MovieListViewScreen.screenId]

    // MARK: Action Elements
    private lazy var logoutButton: XCUIElement = self.app.button(identifier: MovieListAction.logout.identifier)
    private lazy var tableView: XCUIElement = self.app.tableView(identifier: MovieListAction.tableView.identifier)


    init(application: XCUIApplication) {
        self.app = application
    }

    public func waitForScreen(time: TimeInterval) -> Bool {
        return self.screenElement.waitForExistence(timeout: time)
    }

    public func actionONScreen(action: MovieListAction) {
        switch action {
        case .logout:
            self.logoutButton.tap()
        case .tableView:
            self.logoutButton.tap()
        case .tableItem(let itemIndex):
            let cellItem = tableView.listItem(identifier: "movie_item_\(itemIndex)")
            cellItem.tap()
        }
    }
}
