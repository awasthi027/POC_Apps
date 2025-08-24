//
//  KeyWindowGettable.swift
//  CoreHelpers
//
//  Created by Ashish Awasthi on 21/08/25.
//

import UIKit

@discardableResult
public func ensureOnMainQueue<T>(execute work: () throws -> T) rethrows -> T {
    if Thread.isMainThread {
        return try work()
    } else {
        return try DispatchQueue.main.sync(execute: work)
    }
}


/// SDK treats warnings as errors as per Xcode settings.
/// Since SDK does not support multi scenes,  it can continue to use keyWindow on UIApplication.
/// Using this Protocol approach to avoid showing deprecated API error.
/// Usage : `(UIApplication.shared as KeyWindowGettable).keyUIWindow`
internal protocol KeyWindowGettable {
    var keyUIWindow: UIWindow? { get }
}

@available(iOSApplicationExtension, unavailable)
extension UIApplication : KeyWindowGettable {

    @available(iOS, deprecated: 13.0)
    var keyUIWindow: UIWindow? {
        return keyWindow
    }

}
