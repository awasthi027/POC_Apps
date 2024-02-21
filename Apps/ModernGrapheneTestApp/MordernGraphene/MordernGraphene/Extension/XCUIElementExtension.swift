//
//  XCUIElementExtension.swift
//  MordernGraphene
//
//  Created by Ashish Awasthi on 02/02/24.
//

import XCTest


//public extension XCUIElement {
//
//    /// Repeatedly calls `block` until it returns true or `timeout` expires.
//    @available(*, deprecated, message: "Use of block predicates is highly discouraged. Use Predicate<XCUIElement> where possible.")
//    // blocks are discouraged because XCTest prints _very clear_ messages about non-block NSPredicates.
//    func wait(block: @escaping (XCUIElement) -> Bool, timeout: TimeInterval = 30) -> Bool {
//        if block(self) {
//            return true // already meeting the condition
//        }
//
//        let pred = NSPredicate { (obj, _) -> Bool in
//            guard let element = obj as? XCUIElement else {
//                preconditionFailure("Wrong type passed to block from query: \(String(describing: obj)).\nExpected XCUIElement")
//            }
//            return block(element)
//        }
//        let expectation = XCTNSPredicateExpectation(predicate: pred, object: self)
//        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
//    }
//    // a quick extension for isVisbile on an element.
//    var isVisible: Bool {
//        exists && isHittable
//    }
//}
