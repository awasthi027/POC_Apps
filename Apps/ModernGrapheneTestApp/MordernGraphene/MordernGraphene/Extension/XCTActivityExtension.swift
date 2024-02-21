//
//  XCTActivityExtension.swift
//  MordernGraphene
//
//  Created by Ashish Awasthi on 02/02/24.
//

//import Foundation
//import XCTest
//
//extension XCTActivity {
//    fileprivate func attachScreenshot() {
//#if os(iOS) && (targetEnvironment(simulator) || arch(arm64))
//        let attachment = XCTAttachment(image: XCUIScreen.main.screenshot().image, quality: .low)
//        attachment.lifetime = .deleteOnSuccess
//        self.add(attachment)
//#endif
//    }
//
//    func attachElementHierarchy(for elementProviding: GrapheneElementProviding) {
//        let attachment = XCTAttachment(string: elementProviding.element.debugDescription)
//        attachment.lifetime = .deleteOnSuccess
//        attachment.name = "Element-Query.txt"
//        self.add(attachment)
//    }
//
//    func attachScreenHierarchy(for appProviding: AppProviding) {
//        let attachment = XCTAttachment(string: appProviding.app.debugDescription)
//        attachment.lifetime = .deleteOnSuccess
//        attachment.name = "Screen-Hierarchy.txt"
//        self.add(attachment)
//    }
//
//}
//
//
//
//protocol GrapheneElementProviding {
//    var element: XCUIElement { get }
//}
//
//extension FeatureBase: GrapheneElementProviding {}
//
///// Conformers provide an XCUIApplication
//public protocol AppProviding {
//    var application: XCUIApplication { get }
//}
//
//public extension AppProviding {
//    var app: XCUIApplication {
//        self.application
//    }
//}
//
//extension FeatureBase: AppProviding {}
//
///// A @_functionBuilder which creates a Feature out of a single-expression XCUIElement
//@resultBuilder
//@available(*, deprecated, message: "Remove @FeatureBuilder<...> and use inline feature {...} syntax within the method.")
//public struct FeatureBuilder<Return: FeatureBase> {
//    /// Creates a Feature out of a single-expression XCUIElement
//    public static func buildBlock(_ query: @escaping @autoclosure () -> XCUIElement, file: StaticString = #file, line: UInt = #line, function: StaticString = #function) -> Return {
//        let bogusApp = XCUIApplication(bundleIdentifier: "If you are seeing this bundleId then you're still using @FeatureBuilder. Please transition the inline feature {...} syntax. ")
//        let feature = Return.init(name: function.description, app: bogusApp, element: query)
////        _ = noTraceFlow { // for EFT
////            feature.validate()
////        }
//        if feature.validationStatus == .failed {
//            XCTFail("\(Return.self) matching (\(query())) could not be found", file: file, line: line)
//        }
//        return feature
//    }
//}
