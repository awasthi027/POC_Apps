//
//  Validatable.swift
//  MordernGraphene
//
//  Created by Ashish Awasthi on 02/02/24.
//


import Foundation

//public enum ValidationStatus {
//    case untried
//    case validated
//    case failed
//}
//
//public protocol Validatable {
//    var validationStatus: ValidationStatus { get }
//
//    func validate(timeout: TimeInterval) -> Bool
//}
//
//public extension Validatable {
//    func validate(timeOut: TimeInterval = 30) -> Bool {
//        self.validate(timeout: timeOut)
//    }
//}
//
//extension Validatable {
//    public var validated: Bool {
//        switch self.validationStatus {
//        case .failed:
//            return false
//        case .validated:
//            return true
//        case .untried:
//            return self.validate()
//        }
//    }
//}
