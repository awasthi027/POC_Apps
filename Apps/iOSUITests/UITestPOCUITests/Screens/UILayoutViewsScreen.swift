//
//  UILayoutViewsScreen.swift
//  UITestPOCUITests
//
//  Created by Ashish Awasthi on 22/01/24.
//


import XCTest

public enum UILayoutViewsScreenAction: Int {
    case sharePDF
    case searchTextField
    case actionSheetAction
    // MARK: Identifiers
    var identifier: String {
        switch self {
        case .sharePDF: return "sharePDFButton"
        case .searchTextField: return "searchTextField"
        case .actionSheetAction: return "actionSheetButton"
        }
    }
}

public final class UILayoutViewsScreen: SDKScreenProtocol {

    private var app: XCUIApplication
    static let screenId: String = "UILayoutViewsScreen"
    private lazy var screenElement: XCUIElement = self.app.staticTexts[HomeViewScreen.screenId]

    // MARK: Action Elements
    private lazy var sharePDFButton: XCUIElement = self.app.button(identifier: UILayoutViewsScreenAction.sharePDF.identifier)
    private lazy var actionSheetButton: XCUIElement = self.app.button(identifier: UILayoutViewsScreenAction.actionSheetAction.identifier)
    private lazy var searchTextField: XCUIElement = self.app.textFields(identifier: UILayoutViewsScreenAction.searchTextField.identifier)


    init(application: XCUIApplication) {
        self.app = application
    }

    @discardableResult  public func waitForScreen(time: TimeInterval) -> Bool {
        return self.screenElement.waitForExistence(timeout: time)
    }

    public func actionONScreen(action: UILayoutViewsScreenAction) {
        switch action {
        case .sharePDF:
            self.sharePDFButton.tap()
        case .searchTextField:
            self.selectCopyFromActivityController()
            self.searchTextField.tap()
            searchTextField.doubleTap()
            let element = self.app.menuItem(identifier: ContextMenuOption.paste.identifier)
            element.tap()
        case .actionSheetAction:
            self.actionSheetButton.tap()
            self.app.button(identifier: "Green").tap()
        }
    }

    internal func selectCopyFromActivityController() {
        let activityListView = app.tableView(identifier: ContextMenuOption.tableIdentifier)
        let element = activityListView.listItem(identifier: ContextMenuOption.copy.identifier)
        element.tap()
    }

    internal func copyAndPasteText() {
        let navnTextField = self.searchTextField
        self.searchTextField.tap()
        UIPasteboard.general.string = "Henrik"
        self.searchTextField.doubleTap()
        // Menu Paste Item
        app.menuItems.element(boundBy: 0).tap()
        XCTAssertEqual(navnTextField.value as? String, "Henrik")
    }

    func typeTextSelectTextCopyTextPasteTextAndReadText(typeText: String) -> String {
        self.searchTextField.tap()
        self.searchTextField.clearAndTypeText(typeText: typeText)

        self.searchTextField.longPress()
        let selectElement = self.app.menuItem(identifier: ContextMenuOption.select.identifier)
        selectElement.tap()


        let copyElement = self.app.menuItem(identifier: ContextMenuOption.copy.identifier)
        copyElement.tap()

        // Wait to clear complete text
        self.searchTextField.tap()
        self.searchTextField.clearAndTypeText(typeText: "")
        XCTAssertTrue(self.searchTextField.waitForExistence(timeout: 3))

        self.searchTextField.longPress()
        let pasteElement = self.app.menuItem(identifier: ContextMenuOption.paste.identifier)
        pasteElement.tap()

        //The only way I am able to retrieve URL Bar value in Safari App
        let result = self.searchTextField.value as? String
        return result ?? ""
    }

    @discardableResult  func shareDocWith(app: String) -> Bool {
        let isHittablePredicate = NSPredicate(format: "isHittable == true")
        let sharingApp = self.app.scrollViews.cells.firstMatch

        let expectation1 = XCTNSPredicateExpectation(predicate: isHittablePredicate, object: sharingApp)
        _ = XCTWaiter().wait(for: [expectation1], timeout: 10.0)
        return  sharingApp.tapIfExists()
    }
}


