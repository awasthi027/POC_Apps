//
//  Swizzler.swift
//  CoreHelpers
//
//  Created by Ashish Awasthi on 12/08/25.
//

import Foundation

public final class Swizzler {

    static func getMethod(
        from `class`: AnyClass?,
        with signature: Selector,
        isClassMethod: Bool
    ) -> Method? {
        `class`.flatMap {
            isClassMethod
                ? ObjectiveC.class_getClassMethod($0, signature)
                : ObjectiveC.class_getInstanceMethod($0, signature)
        }
    }

    @discardableResult
    static func added(
        method: Method,
        to `class`: AnyClass?,
        as signature: Selector,
        isClassMethod: Bool
    ) -> Method? {
        `class`
            .flatMap { isClassMethod ? ObjectiveC.object_getClass($0) : $0 }
            .flatMap { targetClass in
                ObjectiveC.class_addMethod(
                    targetClass,
                    signature,
                    ObjectiveC.method_getImplementation(method),
                    ObjectiveC.method_getTypeEncoding(method)
                )
            }.flatMap { _ in
                self.getMethod(from: `class`, with: signature, isClassMethod: isClassMethod)
            }
    }

    static func swizzleMethods(
        origin: ObjectiveC.Method?,
        target: ObjectiveC.Method?
    ) {
        origin
            .pair(with: target)
            .flatMap(ObjectiveC.method_exchangeImplementations)
    }

    static func swizzleInstanceMethods(
        `class`: AnyClass?,
        origin: Selector,
        target: Selector
    ) {
        self.swizzle(
            origin: (class: `class`, selector: origin, isClassMethod: false),
            target: (class: `class`, selector: target, isClassMethod: false)
        )
    }

    static func swizzle(
        origin: (`class`: AnyClass?, selector: Selector, isClassMethod: Bool),
        target: (`class`: AnyClass?, selector: Selector, isClassMethod: Bool)
    ) {
        self
            .getMethod(
                from: target.class,
                with: target.selector,
                isClassMethod: target.isClassMethod
            )
            .flatMap { method in
                self.added(
                    method: method,
                    to: origin.class,
                    as: target.selector,
                    isClassMethod: origin.isClassMethod
                )
            }
            .flatMap { addedMethod in
                self.swizzleMethods(
                    origin: addedMethod,
                    target: self.getMethod(
                        from: origin.class,
                        with: origin.selector,
                        isClassMethod: origin.isClassMethod
                    )
                )
            }
    }
}
