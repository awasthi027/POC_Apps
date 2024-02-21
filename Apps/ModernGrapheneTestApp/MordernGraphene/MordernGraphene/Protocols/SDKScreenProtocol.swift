//
//  SDKScreenProtocol.swift
//  MordernGraphene
//
//  Created by Ashish Awasthi on 02/02/24.
//

//import Foundation
//import XCTest
//
////app needs a bundle id
//public protocol GrapheneApplicationProtocol {
//    //var bundleID: String {get}
//    var application: XCUIApplication { get }
//}
//
////screen needs to know which app it belongs to
//@available(*, deprecated, message: "SDKScreenProtocol has been refactored to use FeatureValidatedScreen. Will be removed.")
//public protocol SDKScreenProtocol {
//    var screenIdentifier: String { get }
//    func waitForScreen(time: TimeInterval) -> Bool
//    func waitForScreenToDisappear(time: TimeInterval) -> Bool
//}
//
//@available(*, deprecated, message: "SDKScreenProtocol has been refactored to use FeatureValidatedScreen. Will be removed.")
//public extension SDKScreenProtocol {
//    var screenIdentifier: String {
//        "default"
//    }
//    func waitForScreenToDisappear(time: TimeInterval = 30) -> Bool {
//        XCTFail("waitForScreenToDisappear(time: TimeInterval = 30) is not implemented by default. Needs to be implented by the class adopting this protocol")
//        return false
//    }
//}
