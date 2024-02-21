//
//  FeatureBase.swift
//  MordernGraphene
//
//  Created by Ashish Awasthi on 02/02/24.
//

//import Foundation
//import XCTest
//
//open class FeatureBase : Waitable, Validatable {
//
//    public let name: String
//    public let application: XCUIApplication
//    private let query: () -> XCUIElement
//    internal var element: XCUIElement {
//        query().firstMatch
//    }
//
//    fileprivate(set) public var validationStatus = ValidationStatus.untried
//
//    public required init(name: String, app: XCUIApplication, element: @escaping () -> XCUIElement) {
//        self.name = name
//        self.application = app
//        self.query = element
//    }
//
//    public func validate(timeout: TimeInterval = 30) -> Bool {
//        guard self.validationStatus != .failed else { return false }
//        guard self.validationStatus != .validated else { return true }
//
//        return XCTContext.runActivity(named: "Validating \(self.name)") { context in
//            let appeared = self.await(timeout: timeout)
//            if !appeared {
//                context.attachScreenHierarchy(for: self)
//                context.attachElementHierarchy(for: self)
//            }
//            self.validationStatus = appeared ? .validated : .failed
//            return appeared
//        }
//    }
//
//    public var isVisible: Bool {
//        self.element.isVisible
//    }
//
//    public var frame: CGRect {
//        self.element.frame
//    }
//}
