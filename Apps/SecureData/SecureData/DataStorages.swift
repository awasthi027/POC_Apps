//
//  DataStorages.swift
//  
//
//  Created by Ashish Awasthi on 15/06/25.
//

public protocol DataRepresentable {
    func toData() -> Data?
    static func from(data: Data?) -> Self?
}

public protocol StoreSecurityProvider {
    func encrypt(object: DataRepresentable?) -> Data?
    func decrypt<D: DataRepresentable>(data: Data?) -> D?

    func wrap(object: DataRepresentable?) -> Data?
    func unwrap<D: DataRepresentable>(data: Data?) -> D?
}

public protocol AbstractKeyValueStore {
    var securityProvider: StoreSecurityProvider? { get set }
    @discardableResult
    mutating func clear(group: String) -> Bool

    func get<D: DataRepresentable>(group: String, key: String) -> D?

    @discardableResult
    mutating func set<D: DataRepresentable>(group: String, key: String, value: D?) -> Bool

    func getlastUpdatedTimestamp(group: String, key: String) -> TimeInterval?

    func readKey<D: DataRepresentable>(group: String, key: String) -> D?

    @discardableResult
    mutating func saveKey<D: DataRepresentable>(group: String, key: String, value: D?) -> Bool
}

public struct KeychainDataStore: AbstractKeychainDataStore {
    public var securityProvider: StoreSecurityProvider?
    public init() {
        // To provide a public initializer for KeychainDataStore
    }
}

public protocol AbstractDataStoreAccessibilityProvider {
    func set<D: DataRepresentable>(group: String, key: String, deviceOnlyValue: D?) -> Bool
    func updateAccessibilityToThisDeviceOnly(group: String, key: String) -> Bool
}

public protocol AbstractKeychainDataStore: AbstractKeyValueStore, AbstractDataStoreAccessibilityProvider { }
internal let keychainSafeGuardLock = NSRecursiveLock()

public extension AbstractKeychainDataStore {
    internal func genericQuery(group: String, service: String) -> [String: AnyObject] {
        return [
            String(kSecClass): kSecClassGenericPassword,
            String(kSecAttrAccount): group as AnyObject,
            String(kSecAttrService): service as AnyObject
        ]
    }

    func get<D: DataRepresentable>(group: String, key: String) -> D? {
        keychainSafeGuardLock.lock()
        defer {
            keychainSafeGuardLock.unlock()
        }

        let keychainReturnedData = self.readDataFromKeychain(group: group, key: key)
        guard let decryptor = self.securityProvider else {
            return D.from(data: keychainReturnedData)
        }
        return decryptor.decrypt(data: keychainReturnedData)
    }

    internal func readDataFromKeychain(group: String, key: String) -> Data? {
        keychainSafeGuardLock.lock()
        defer {
            keychainSafeGuardLock.unlock()
        }

        guard group.isEmpty == false, key.isEmpty == false else {
            return nil
        }
        var query = self.genericQuery(group: group, service: key)
        query[String(kSecMatchLimit)] = String(kSecMatchLimitOne) as AnyObject
        query[String(kSecReturnData)] = true as AnyObject
        var data: AnyObject?
        let result = SecItemCopyMatching(query as CFDictionary, &data)
        let success = result == noErr || result == errSecItemNotFound
        if success == false {
            let message = "Keychain read Error Code : \(result)"
            //LogError(message)
            assertionFailure(message)
        }
        return data as? Data
    }

    internal func saveDataToKeychain(group: String, key: String, accessibility: KeychainDataStoreAccessibility, value: Data?) -> Bool {
        keychainSafeGuardLock.lock()
        defer {
            keychainSafeGuardLock.unlock()
        }

        guard group.isEmpty == false, key.isEmpty == false else {
            return false
        }
        let itemQuery = self.genericQuery(group: group, service: key)

        guard let newValue = value else {
            return self.delete(query: itemQuery)
        }
        var rawItemQuery = itemQuery
        rawItemQuery[String(kSecMatchLimit)] = String(kSecMatchLimitOne) as AnyObject
        rawItemQuery[String(kSecReturnData)] = true as AnyObject
        var rawData: AnyObject?
        let result = SecItemCopyMatching(rawItemQuery as CFDictionary, &rawData)
        if result == errSecItemNotFound {
            return self.add(query: itemQuery, accessibility: accessibility, data: newValue)
        }

        guard result == noErr else {
            let message = "Keychain write Error Code : \(result)"
           // LogError(message)
            assertionFailure(message)
            return self.add(query: itemQuery, accessibility: accessibility, data: newValue)
        }

        return self.update(query: itemQuery, accessibility: accessibility, data: newValue)
    }

    internal func zeroOutExistingData(group: String, key: String) -> Bool {
        keychainSafeGuardLock.lock()
        defer {
            keychainSafeGuardLock.unlock()
        }

        guard var data = self.readDataFromKeychain(group: group, key: key) else {
            // Empty keychain entry. No need to do anything.
            return true
        }
        data = Data.generateStaticPattern(size: data.count)
        let itemQuery = self.genericQuery(group: group, service: key)
        guard self.update(query: itemQuery, accessibility: .firstUnlock, data: data),
            let zeroedData = self.readDataFromKeychain(group: group, key: key) else {
            // written data filled with zeros, but not able to read after this.
            return false
        }

        return data == zeroedData
    }

    internal func delete(query: [String: AnyObject]) -> Bool {
        keychainSafeGuardLock.lock()
        defer {
            keychainSafeGuardLock.unlock()
        }

        let result = SecItemDelete(query as CFDictionary)
        guard result == noErr || result == errSecItemNotFound else {
            let message = "Keychain Delete Error Code : \(result)"
           // LogError(message)
            assertionFailure(message)
            return false
        }
        return true
    }

    internal func update(query: [String: AnyObject], accessibility: KeychainDataStoreAccessibility, data: Data) -> Bool {
        keychainSafeGuardLock.lock()
        defer {
            keychainSafeGuardLock.unlock()
        }

        var updateAttributes = [String: AnyObject]()
        updateAttributes[String(kSecValueData)] = data as AnyObject
        updateAttributes[String(kSecAttrModificationDate)] = Date() as AnyObject
        updateAttributes[String(kSecAttrAccessible)] = accessibility.value

        let result = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)
        guard result == noErr else {
            let message = "Keychain Update Error Code:\(result)"
           // LogError(message)
            assertionFailure(message)
            return false
        }
        return true
    }

    internal func add(query: [String: AnyObject], accessibility: KeychainDataStoreAccessibility, data: Data) -> Bool {
        keychainSafeGuardLock.lock()
        defer {
            keychainSafeGuardLock.unlock()
        }

        var queryCopy = query
        queryCopy[String(kSecValueData)] = data as AnyObject
        queryCopy[String(kSecAttrCreationDate)] = Date() as AnyObject
        queryCopy[String(kSecAttrAccessible)] = accessibility.value

        let result = SecItemAdd(queryCopy as CFDictionary, nil)
        guard result == noErr else {
            let message = "Keychain add Error Code:\(result)"
         //   LogError(message)
            assertionFailure(message)
            return false
        }
        return true
    }

    @discardableResult
    mutating func set<D: DataRepresentable>(group: String, key: String, value: D?) -> Bool {
        keychainSafeGuardLock.lock()
        defer {
            keychainSafeGuardLock.unlock()
        }

        guard group.isEmpty == false, key.isEmpty == false else {
            return false
        }
        var dataValue: Data? = nil

        if let encryptor = self.securityProvider,
            let newValue = value {
            dataValue = encryptor.encrypt(object: newValue)
        } else {
            dataValue = value?.toData() as Data?
        }

        return self.saveDataToKeychain(group: group, key: key, accessibility: .firstUnlock, value: dataValue)
    }

    func getlastUpdatedTimestamp(group: String, key: String) -> TimeInterval? {
        keychainSafeGuardLock.lock()
        defer {
            keychainSafeGuardLock.unlock()
        }

        var itemQuery = self.genericQuery(group: group, service: key)
        itemQuery[String(kSecMatchLimit)] = String(kSecMatchLimitOne) as AnyObject
        itemQuery[String(kSecReturnAttributes)] = true as AnyObject

        var result: AnyObject? = nil
        let operationResult = SecItemCopyMatching(itemQuery as CFDictionary, &result)

        guard operationResult == noErr,
            let resultDictionary = result as? [String: AnyObject],
            let modificationDate = resultDictionary[String(kSecAttrModificationDate)] as? Date
            else {
                return nil
        }
        return modificationDate.timeIntervalSince1970
    }

    mutating func clear(group: String) -> Bool {
        keychainSafeGuardLock.lock()
        defer {
            keychainSafeGuardLock.unlock()
        }

        let query: [String: AnyObject] = [
            String(kSecClass): kSecClassGenericPassword,
            String(kSecAttrAccount): group as AnyObject
        ]

        let result: OSStatus = SecItemDelete(query as CFDictionary)

        guard result == noErr else {
          //  LogError(" Remove all error code: \(result)")
            return false
        }
        return true
    }
}

public extension AbstractKeychainDataStore {

    func set<D: DataRepresentable>(group: String, key: String, deviceOnlyValue: D?) -> Bool {
        keychainSafeGuardLock.lock()
        defer {
            keychainSafeGuardLock.unlock()
        }
        guard group.isEmpty == false, key.isEmpty == false else {
            return false
        }
        var dataValue: Data? = nil

        if let encryptor = self.securityProvider,
           let newValue = deviceOnlyValue {
            dataValue = encryptor.encrypt(object: newValue)
        } else {
            dataValue = deviceOnlyValue?.toData() as Data?
        }
        return self.saveDataToKeychain(group: group, key: key, accessibility: .firstUnlockThisDeviceOnly, value: dataValue)
    }

    func updateAccessibilityToThisDeviceOnly(group: String, key: String) -> Bool {
//        keychainSafeGuardLock.lock()
//        defer {
//            keychainSafeGuardLock.unlock()
//        }
//        guard let value: Data = self.get(group: group, key: key) else {
//            return false
//        }
//        return self.saveDataToKeychain(group: group, key: key, accessibility: .firstUnlockThisDeviceOnly, value: value)
        return true
    }
}

public extension AbstractKeychainDataStore {

    func readKey<D: DataRepresentable>(group: String, key: String) -> D? {
        keychainSafeGuardLock.lock()
        defer {
            keychainSafeGuardLock.unlock()
        }

        let keychainReturnedData = self.readDataFromKeychain(group: group, key: key)
        guard let keyWrapper = self.securityProvider else {
            return D.from(data: keychainReturnedData)
        }
        return keyWrapper.unwrap(data: keychainReturnedData)
    }

    @discardableResult
    mutating func saveKey<D: DataRepresentable>(group: String, key: String, value: D?) -> Bool {
        keychainSafeGuardLock.lock()
        defer {
            keychainSafeGuardLock.unlock()
        }

        guard group.isEmpty == false, key.isEmpty == false else {
            return false
        }
        var dataValue: Data? = nil
        if let keyWrapper = self.securityProvider,
            let newValue = value {
            dataValue = keyWrapper.wrap(object: newValue)
        } else {
            dataValue = value?.toData() as Data?
        }

        guard self.zeroOutExistingData(group: group, key: key) else {
            return false
        }

        return self.saveDataToKeychain(group: group, key: key, accessibility: .firstUnlock, value: dataValue)
    }
}

public extension Data {
    internal static func generateStaticPattern(size: Int) -> Data {
        // Start out with the pattern from 0xBEE5F00D and size it for the given size above
        let hexPattern = [UInt32](repeating: 0x0DF0E5BE, count: size / 4 + 1)
        // Return new data object with pattern of given size.
        return Data(bytes: hexPattern, count: size)
    }
}

internal protocol AccessibilityOptions {
    var value: AnyObject { get }
}

internal enum KeychainDataStoreAccessibility: AccessibilityOptions {
    var value: AnyObject {
        if self == .firstUnlockThisDeviceOnly {
            return String(kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly) as AnyObject
        }
        return String(kSecAttrAccessibleAfterFirstUnlock) as AnyObject
    }
    case firstUnlock
    case firstUnlockThisDeviceOnly
}
