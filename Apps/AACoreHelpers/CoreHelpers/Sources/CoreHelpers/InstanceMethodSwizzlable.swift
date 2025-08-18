//
//  InstanceMethodSwizzlable.swift
//  CoreHelpers
//
//  Created by Ashish Awasthi on 12/08/25.
//


import Foundation

#if os(iOS)
import UIKit
import WebKit

internal protocol TargetedInstanceProvider {
    var targetedInstance: Any { get }
}

extension TargetedInstanceProvider where Self: NSObjectProtocol {
    var targetedInstance: Any {
        if let view = self as? UIView,
           let targetView = view.superview?.superview,
           targetView is WKWebView {
            return targetView as Any
        }

        return self
    }
}

extension UIResponder: TargetedInstanceProvider { }

internal protocol InstanceMethodSwizzlable: TargetedInstanceProvider {
    static var targetedClass: AnyClass? { get }
    static var shouldSwizzle: Bool { get }
    static func swizzleInstanceMethod(from original: Selector, to targeted: Selector)
    static func swizzleInstanceMethod(
        origin: (`class`: AnyClass?, selector: Selector),
        target: (`class`: AnyClass?, selector: Selector)
    )
}

extension InstanceMethodSwizzlable {
    static func swizzleInstanceMethod(from original: Selector, to targeted: Selector) {
        guard self.shouldSwizzle else {
            return
        }
        Swizzler.swizzleInstanceMethods(
            class: self.targetedClass,
            origin: original,
            target: targeted
        )
    }

    static func swizzleInstanceMethod(
        origin: (`class`: AnyClass?, selector: Selector),
        target: (`class`: AnyClass?, selector: Selector)
    ) {
        guard self.shouldSwizzle else {
            return
        }
        Swizzler.swizzle(origin: (class: origin.class, selector: origin.selector, isClassMethod: false),
                         target: (class: target.class, selector: target.selector, isClassMethod: false))
    }
}

extension InstanceMethodSwizzlable where Self: NSObjectProtocol {

    static var shouldSwizzle: Bool {
        return true
    }

    static var targetedClass: AnyClass? {
        return self
    }
}

#endif
