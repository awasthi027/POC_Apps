//
//  UserDefaults.swift
//  ResultBuilderPOC
//
//  Created by Ashish Awasthi on 12/10/23.
//

import Foundation

private protocol AnyOptional {
    var isNil: Bool { get }
}

extension Optional: AnyOptional {
    var isNil: Bool { self == nil }
}

@objc protocol Container {
    func object(for key: String) -> Any?
    func set(object: Any, for key: String)
    func removeObject(for key: String)
}

// We store some items in shared userdefaults to be used by extension.
enum UserDefaultsType {
    // will set UserDefaults.standard
    case standard
    // will set UserDefaults.init(suiteName: suiteName)
    case shared
}

class UserDefaultsStore: Container {

    var userDefaults: UserDefaults? = .standard

    /// Instantiates UserDefaultsStore
    /// - Parameters:
    ///   - type: Specify it to be standard or shared.
    ///   - suiteName: custom suitename can be provided, escpecially for tests.
    init(type: UserDefaultsType = .standard, suiteName: String = "group.com.testpoc.app") {
        self.userDefaults = (type == .shared) ? UserDefaults(suiteName: suiteName) : UserDefaults.standard
    }

    func object(for key: String) -> Any? {
        return self.userDefaults?.object(forKey: key)
    }

    func set(object: Any, for key: String) {
        self.userDefaults?.set(object, forKey: key)
        self.userDefaults?.synchronize()
    }

    func removeObject(for key: String) {
        self.userDefaults?.removeObject(forKey: key)
        self.userDefaults?.synchronize()
    }
}


@propertyWrapper
struct Persist<Value> {
    let key: String
    let defaultValue: Value
    let container: Container

    init(key: String, 
         defaultValue: Value,
         container: Container = UserDefaultsStore()) {
        self.key = key
        self.defaultValue = defaultValue
        self.container = container
    }

    var wrappedValue: Value {
        get {
            let value = container.object(for: key) as? Value
            return value ?? defaultValue
        }
        set {
            if let optional = newValue as? AnyOptional, optional.isNil {
                container.removeObject(for: key)
            } else {
                container.set(object: newValue, for: key)
            }
        }
    }
}

/// How to access value
extension UserDefaults {
    @Persist(key: "isUserLogin",
             defaultValue: false)
   static var isUserLogin: Bool
}
