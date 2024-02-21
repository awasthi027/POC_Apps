//
//  ModernGraphenFeature.swift
//  UITestPOCUITests
//
//  Created by Ashish Awasthi on 05/02/24.
//

import XCTest

import Foundation

public func +<A,B,C>(lhs: @escaping (A)->B, rhs: @escaping (B)->C) -> (A)->C {
    { rhs(lhs($0)) }
}

public func +<A,B,C>(lhs: KeyPath<A,B>, rhs: @escaping (B)->C) -> (A)->C {
    { rhs($0[keyPath: lhs]) }
}

public func +<A,B,C>(lhs: @escaping (A)->B, rhs: KeyPath<B,C>) -> (A)->C {
    { lhs($0)[keyPath: rhs] }
}


public enum ValidationStatus {
    case untried
    case validated
    case failed
}

public protocol Validatable {
    var validationStatus: ValidationStatus { get }

    func validate(timeout: TimeInterval) -> Bool
}

public extension Validatable {
    func validate() -> Bool {
        self.validate(timeout: 30)
    }
}

extension Validatable {
    public var validated: Bool {
        switch self.validationStatus {
        case .failed:
            return false
        case .validated:
            return true
        case .untried:
            return self.validate()
        }
    }
}

extension XCUIElement {
    /// Repeatedly calls `block` until it returns true or `timeout` expires.
    @available(*, deprecated, message: "Use of block predicates is highly discouraged. Use Predicate<XCUIElement> where possible.")
    // blocks are discouraged because XCTest prints _very clear_ messages about non-block NSPredicates.
    func wait(block: @escaping (XCUIElement) -> Bool, timeout: TimeInterval = 30) -> Bool {
        if block(self) {
            return true // already meeting the condition
        }

        let pred = NSPredicate { (obj, _) -> Bool in
            guard let element = obj as? XCUIElement else {
                preconditionFailure("Wrong type passed to block from query: \(String(describing: obj)).\nExpected XCUIElement")
            }
            return block(element)
        }
        let expectation = XCTNSPredicateExpectation(predicate: pred, object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
public protocol Waitable: FeatureBase {}
public extension Waitable {
    @available(*, deprecated, renamed: "validated")
    var exists: Bool {
        self.element.exists
    }

    func await(timeout: TimeInterval = 30) -> Bool {
        self.element.waitForExistence(timeout: timeout)
    }

    func await(_ block: @escaping (Self) -> Bool, timeout: TimeInterval = 30) -> Bool {
        self.element.wait(block: { _ in
            block(self) // this reference cycle is temporary
        }, timeout: timeout)
    }
}
/// The abstract base class of all concrete features
open class FeatureBase : Waitable, Validatable {

    public let name: String
    public let application: XCUIApplication
    private let query: () -> XCUIElement
    internal var element: XCUIElement {
        query().firstMatch
    }

   fileprivate(set) public var validationStatus = ValidationStatus.untried

    public required init(name: String, app: XCUIApplication, element: @escaping () -> XCUIElement) {
        self.name = name
        self.application = app
        self.query = element
    }

    public func validate(timeout: TimeInterval = 30) -> Bool {
        guard self.validationStatus != .failed else { return false }
        guard self.validationStatus != .validated else { return true }

        return XCTContext.runActivity(named: "Validating \(self.name)") { context in
            let appeared = self.await(timeout: timeout)
            if !appeared {
//                context.attachScreenHierarchy(for: self)
//                context.attachElementHierarchy(for: self)
            }
            self.validationStatus = appeared ? .validated : .failed
            return true
        }
    }

    public var isVisible: Bool {
       // self.element.isVisible
        return true
    }

    public var frame: CGRect {
        self.element.frame
    }
}

/// A protocol which imparts polymorphic "Self"-ness into Screens
/// Conforming to this protocol enables the @Feature syntax
public protocol FeatureDeclaring: AppProviding, SDKScreenProtocol {
    /// A typealias providing @Feature syntax for this screen
    typealias Feature<Return: FeatureBase> = ScreenFeature<Self, Return>
}

/** AbstractScreenInteraction defines a contract for building property wrappers for Graphene screens.
*  An interaction is defined by a timeout a fulfillment function, which receives the Screen instance
*  to which this declaration belongs and which returns an unconstrained `Return` value.
*  Most subclasses should constrain the Return type to be `FlowResult` which at minimum is
*  interpreted to represent the success or failure of the interaction. If the interaction takes longer than
*  timeout to complete, the interaction is expected to produce a Return value indicating failure, which
*  for subclasses constraining  `Return` to `FlowResult` can be expressed as `Return.unspecifiedFailure` .
*/
public class AbstractScreenInteraction<Screen: SDKScreenProtocol, Return>: InstanceInjectionRecipient<Screen>, DiscoverableProperty {

    /// The unapplied function which implements the interaction
    let fulfillment: (Screen) -> Return
    /// A the maximum amount of time this interaction should wait before failing
    let timeout: TimeInterval

    /// Initializes a AbstractScreenInteraction property wrapper.
    /// - Parameters:
    ///   - timeout: the amount of time to wait for the interaction
    ///   - fulfillment: A function which accepts an `Screen` and returns a Return success/failure.
    ///   - declaration: used for debugging
    public init(timeout: TimeInterval = 30, _ fulfillment: @escaping (Screen) -> Return, declaration: CodeLocation) {
        self.fulfillment = fulfillment
        self.timeout = timeout
        super.init(declaration: declaration)
    }

    /// Initializes a AbstractScreenInteraction property wrapper.
    /// - Parameters:
    ///   - timeout: the amount of time to wait for the interaction
    ///   - fulfillment: A function which accepts an `Screen` and returns a Return success/failure.
    ///   - file: used for debugging
    ///   - line: used for debugging
    public convenience init(timeout: TimeInterval = 30, _ fulfillment: @escaping (Screen) -> Return, file: StaticString = #file, line: UInt = #line) {
        self.init(timeout: timeout, fulfillment, declaration: .init(file, line))
    }

}


public struct FeatureOptions: OptionSet {
    public var rawValue: Int
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Do not validate the presence of this feature on screen appearance
    @available(*, deprecated, renamed: "skip")
    public static let skipAppearance    = FeatureOptions.skip
    /// Do not validate the presence of this feature on screen appearance or disappearance
    public static let skip              = FeatureOptions(rawValue: 1 << 0)
}

/// ScreenFeature is a property wrapper that defines a type-safe, interactable UI feature
/// that exists on this screen. The appearancde seamntic of this feature can be described
/// using the optional FeatureOptions property.
@propertyWrapper
public final class ScreenFeature<Screen: AppProviding & SDKScreenProtocol, Return: FeatureBase>: AbstractScreenInteraction<Screen, XCUIElement> {
    /// A function which takes a XCUIApplication and returns an XCUIElement
    public typealias Query = (XCUIApplication) -> XCUIElement
    private var waitTime: TimeInterval
    internal let options: FeatureOptions

    /// A  function which takes a XCUIApplication and returns a XCUIElement
    /// In most cases this function is supplied as a relative keypath to an XCUIElement
    /// declaration parameter is for XCT debugging when errors are encountered.
    public init(_ queryFunc: @escaping Query, options: FeatureOptions = [], timeout: TimeInterval = 30, declaration: CodeLocation) {
        self.waitTime = timeout
        self.options = options
        super.init(\Screen.app+queryFunc, declaration: declaration)
    }
    

    /// A  function which takes a XCUIApplication and returns a XCUIElement
    /// In most cases this function is supplied as a relative keypath to an XCUIElement
    /// file and line parameters are for XCT debugging when errors are encountered.
    public convenience init(_ queryFunc: @escaping Query, options: FeatureOptions = [], timeout: TimeInterval = 30, file: StaticString = #file, line: UInt = #line) {
        self.init(queryFunc, options: options, timeout: timeout, declaration: .init(file, line))
    }

    fileprivate init(_ queryFunc: @escaping (Screen)->XCUIElement, timeout: TimeInterval = 30,  declaration: CodeLocation) {
        self.options = []
        self.waitTime = timeout
        super.init(queryFunc, declaration: declaration)
    }

    internal func element() -> XCUIElement {
        self.fulfillment(self.instance)
    }

    private var storedFeature: Return?
    private func getFeature() -> Return {
        if let existing = self.storedFeature {
            return existing
        } else {
            let out = Return(name: self.memberName(), app: self.instance.app, element: element)
            if let validatedInstance = self.instance as? Validatable, validatedInstance.validationStatus == .failed {
                out.validationStatus = .failed
            }

            self.storedFeature = out
            return out
        }
    }

    /// The property wrapper getter for this feature. The feature's presence is validated before being returned.
    public var wrappedValue: Return {
       // grapheneTrace(syntax: "@Feature", symbol: self.memberName()) { _ in
            let feature = self.getFeature()
            if feature.validationStatus == .failed {
                return feature // don't try to validate it again
            }

//            let flowSuccess = noTraceFlow { // for EFT; eager forward termination.
//                self.validate(on: feature)
//            }
//            if !flowSuccess {
//                Flow.donateValidationFailure(of: feature)
//            }

            if feature.validationStatus == .failed { // try dev mode. Is anybody is listening out there....
              //  Screen_Feature_Dev_Mode(self.instance, self)
                XCTFail("\(self.memberName()) did not appear when requested", file: self.declaration.file, line: self.declaration.line)
            }
            return feature
        //}
    }

    private func validate(on feature: Return) {
//        let appeared = noTraceFlow { // use flow for EFT
//            feature.validate(timeout: self.waitTime)
//        }
//        if !appeared {
            if self.declaration.file.description != "" {
                XCTFail("\(self.memberName()) failed to appear", file: self.declaration.file, line: self.declaration.line)
            } else {
                XCTFail( "\(self.memberName()) failed to appear")
            }
       // }
    }

    /// Flows can use `$` access to reference to receive an unvalidated Feature.
    /// This behavior is useful for implementing custom waiting semantics.
    ///
    /// ```swift
    /// class ExampleScreen: FeatureValidatedScreen {
    ///     @Feature(\.otherElements["specialThing"], options: .skip)
    ///     var specialThing: FeatureBase
    ///
    ///     func customWaitForSpecialThing() -> Bool {
    ///         for _ in 1...5 {
    ///             guard !self.$specialThing.await(timeout: 1) else {
    ///                 return
    ///             }
    ///             print("OMG!!")
    ///         }
    ///     }
    /// }
    /// ```
    public var projectedValue: Return {
        self.getFeature()
    }
}

