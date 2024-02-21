//
//  Test.swift
//  MordernGraphene
//
//  Created by Ashish Awasthi on 05/02/24.
//

import Foundation

/// A property wrapper which stores values in Thread.current.threadDictionary
@propertyWrapper
public struct ThreadLocal<Value> {
    private let key: String
    private let defaultValue: Value

    /// Standard initializer
    /// - Parameters:
    ///   - key: The key to use when accessing Thread.current.threadDictionary
    ///   - default: The default value to return when no stored value is present
    public init(key: String, default: Value) {
        self.key = key
        self.defaultValue = `default`
    }

    /// Standard initializer
    /// - Parameters:
    ///   - wrappedValue: The default value to return when no stored value is present
    ///   - key: The key to use when accessing Thread.current.threadDictionary
    public init(wrappedValue: Value, key: String) {
        self.init(key: key, default: wrappedValue)
    }

    public var wrappedValue: Value {
        get {
            Thread.current.threadDictionary[key] as? Value ?? self.defaultValue
        }
        set {
            Thread.current.threadDictionary[key] = newValue
        }
    }
}
extension ThreadLocal where Value: OptionalProtocol {
    /// A convenience initializer for use when Value is an Optional. When using this constructor the default value returned is 'nil'
    public init(key: String) {
        self.init(key: key, default: Value._none)
    }
}


public protocol OptionalProtocol {
    associatedtype Wrapped

    static var _none: Self { get }

    var value: Wrapped? { get }
}

extension Optional: OptionalProtocol {
    public static var _none: Optional<Wrapped> {
        Optional<Wrapped>.none
    }

    public var value: Wrapped? { self }
}




@propertyWrapper
public class Atomic<Value> {
    private let lock = NSRecursiveLock()
    private var internalValue: Value

    public init(_ value: Value) {
        self.internalValue = value
    }

    public init(wrappedValue value: Value) {
        self.internalValue = value
    }

    public var wrappedValue: Value {
        get {
            self { $0 }
        }
        set {
            self { $0 = newValue }
        }
    }

    public var projectedValue: Atomic<Value> { self }

    public func get() -> Value {
        self.wrappedValue
    }

    public func set(_ value: Value) {
        self.wrappedValue = value
    }

    @discardableResult
    public func callAsFunction<Result>(_ block: (inout Value) throws -> Result) rethrows -> Result {
        self.lock.lock()
        var localValue = self.internalValue

        defer {
            self.internalValue = localValue
            self.lock.unlock()
        }

        return try block(&localValue)
    }
}


private protocol AnyInstanceRecipient {
    func supplyInstance(_ instance: Any) -> Bool
}

private enum UnclaimedRecipients {
    private static let key = "com.vmware.Variant.InstanceInjectionRecipient.unclaimedWrappers"
    @Atomic
    @ThreadLocal(key: Self.key)
    fileprivate static var unclaimed: Array<AnyInstanceRecipient> = []
}



/// A struct representing a specific location in a swift source code file.
public struct CodeLocation: Encodable, Equatable {
    public let file: StaticString
    public let line: UInt
    public let function: StaticString


    public init(_ file: StaticString,
                _ line: UInt) {
        self.init(file, line, #function)
    }

    public init(_ file: StaticString,
                _ line: UInt,
                _ function: StaticString) {
        self.file = file
        self.line = line
        self.function = function
    }

    public static func here(_ file: StaticString = #file,
                            _ line: UInt = #line,
                            _ function: StaticString = #function) -> CodeLocation {
        .init(file, line, function)
    }
}

extension CodeLocation: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.file)
        hasher.combine(self.line)
        hasher.combine(self.function)
    }
}
extension StaticString: Encodable, Equatable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(String(describing: self))
    }

    public static func ==(lhs: Self, rhs: Self) -> Bool {
        String(describing: lhs) == String(describing: rhs)
    }
}

extension StaticString: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(String(describing: self))
    }
}

/// A superclass for property wrappers which need reference to an instance which declares them.
/// What we want to here is is for an instance property (for example @Screen syntax),
/// to have reference to the instance which declares it (a Screen, for example)
/// but property wrappers are initialized _before_ the `self` reference is valid.
/// So what's a dev to do?
/// Instance injection, obviously.
open class InstanceInjectionRecipient<Instance>: AnyInstanceRecipient {
    private var _instance: Instance?
    public var instance: Instance {
        guard let existing = _instance else {
            preconditionFailure("\(Self.self) was used before its instance was supplied. (Usually done with `claimUnclaimed(with:)`)")
        }
        return existing
    }

    public let declaration: CodeLocation
    public var name: String?

    public init(declaration: CodeLocation) {
        self.declaration = declaration
        self.registerAsUnclaimed()
    }

    private func registerAsUnclaimed() {
        UnclaimedRecipients.unclaimed.append(self as! Self)
    }

    fileprivate func supplyInstance(_ instance: Any) -> Bool {
        assert(self._instance == nil)
        guard let castInstance = instance as? Instance else {
            return false
        }
        self._instance = castInstance
        return true
    }

    /// Implementation of the instance injection. Specifically a type calls this method during
    /// Its init *after* the property wrappers are initialized, supplying the `self` reference.
    public class func claimUnclaimed(with instance: Instance) {
        UnclaimedRecipients.unclaimed = UnclaimedRecipients.unclaimed.filter { recipient in
            !recipient.supplyInstance(instance)
        }
    }
}

import XCTest

//screen needs to know which app it belongs to
@available(*, deprecated, message: "SDKScreenProtocol has been refactored to use FeatureValidatedScreen. Will be removed.")
public protocol SDKScreenProtocol {
    var screenIdentifier: String { get }
    func waitForScreen(time: TimeInterval) -> Bool
    func waitForScreenToDisappear(time: TimeInterval) -> Bool
}

@available(*, deprecated, message: "SDKScreenProtocol has been refactored to use FeatureValidatedScreen. Will be removed.")
public extension SDKScreenProtocol {
    var screenIdentifier: String {
        "default"
    }
    func waitForScreenToDisappear(time: TimeInterval = 30) -> Bool {
        XCTFail("waitForScreenToDisappear(time: TimeInterval = 30) is not implemented by default. Needs to be implented by the class adopting this protocol")
        return false
    }
}

/// An SDKScreenProtocol that is initialized with an XCUIApplication
public protocol InitializableScreen: SDKScreenProtocol, AppProviding {
    init<AppProvider: AppProviding>(_ appProviding: AppProvider)
}

/// Conformers provide an XCUIApplication
public protocol AppProviding {
    var application: XCUIApplication { get }
}

public extension AppProviding {
    var app: XCUIApplication {
        self.application
    }
}

/// A protocol which marks instance members which conform as discoverable at runtime and captures the member name.
/// This is primarily useful for property wrapper development.
public protocol DiscoverableProperty: AnyObject {
    var name: String? { get set }
}

extension DiscoverableProperty {
    public func memberName() -> String {
        guard let name = self.name else {
            preconditionFailure("Member name not yet discovered. Call discoverMembers(of:) first.")
        }
        return name
    }
}


/**
 * AppScreen is a property wrapper implementing the factory pattern for InitializableScreen.
 * Subclasses of BasicGrapheneApp need only declare a screen wit the @Screen syntax to use this type.
 * Example:
 * ```
 * @Screen var mainScreen: MainScreen
 * ```
 * The above defines a property called `mainScreen` which creates instances of `MainScreen` which conforms to `ValidatableScreen`
 * Note that each reference to `mainScreen` will receive a new, instantiation of `MainScreen`.
 */
@propertyWrapper
public class AppScreen<Instance: AppProviding, Screen: InitializableScreen>: InstanceInjectionRecipient<Instance>, DiscoverableProperty {

    private let waitTime: TimeInterval
    public init(timeout: TimeInterval = 30, file: StaticString = #file, line: UInt = #line) {
        self.waitTime = timeout
        super.init(declaration: .init(file, line))
    }
    /// Implement the property wrapper protocol by generating a Screen instance.
    public var wrappedValue: Screen {
        let instance = self.instance
            let screen = Screen(instance)
            return screen
    }

    private func validate(on screen: Screen) {
//        let appeared = noTraceFlow { // use flow for EFT
//            screen.validate(timeout: self.waitTime)
//        }
//        if !appeared {
            if self.declaration.file.description != "" {
                XCTFail("\(self.memberName()) failed to appear", file: self.declaration.file, line: self.declaration.line)
            } else {
                XCTFail( "\(self.memberName()) failed to appear")
            }
       // }
    }
}

/// This protocol has no API. It's one purpose is to impart `Self`ness into the contained typealias.
public protocol ScreenDeclaring: AppProviding {
    /// Defines a typealias called Screen which is a partially-applied generic of AppScreen
    /// where the App generic parameter is supplied by `Self`
    typealias Screen<Screen: InitializableScreen> = AppScreen<Self, Screen>
}

