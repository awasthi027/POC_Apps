//
//  DataStorageStructure.swift
//  SecureData
//
//  Created by Ashish Awasthi on 11/07/25.
//
internal protocol SDKContext {
    var applicationKey: String? { mutating get set }
}

internal class AppDataStore {

    internal var itemQueryProvider: KeyValueStoreItemQueryProvider = .nonSharedItem

    /// Data Store that uses vendor specific key to encrypt information. This will faciliate saveing cluster specific senstive information.
    @Synchronized internal var dynamicStore: AbstractKeyValueStore = KeychainDataStore()

    /// Master Data store with PBE Protection. Most Secure Store of all can be used to save any sensitive information.
    @Synchronized internal var masterDataStore: AbstractKeyValueStore = KeychainDataStore()
}

extension AppDataStore: SDKContext {

    var applicationKey: String? {
        get {
            return ""
        }
        set {
            // We can save in master
            //self.masterDataStore
            // We can save in applicay
            // self.dynamicStore
        }
    }
}

protocol MasterKeyMaker {
    var masterKeyWrappedWithCryptKey: Data? { get set }
}

internal struct MasterKeyProvider: MasterKeyMaker  {
    var masterKeyWrappedWithCryptKey: Data?
}


internal class ApplicationDataStoreLocker {

    var itemQueryProvider: KeyValueStoreItemQueryProvider
    var securingDatastore: AppDataStore
    var keyMaker: MasterKeyMaker

    internal init(dataStore: AppDataStore) {
        self.securingDatastore = dataStore
        self.itemQueryProvider = dataStore.itemQueryProvider
        self.keyMaker = MasterKeyProvider()
    }

    var isInitialized: Bool {
        // even in strict mode (if we upgrade to strict mode with Biometric ID mode)
        // there will be a short duration of time where we will have only encrypted cryptkey entry.
        return self.keyMaker.masterKeyWrappedWithCryptKey != nil
    }

    func lockDataStore() -> Bool {
        self.securingDatastore.masterDataStore.securityProvider = nil
        self.securingDatastore.dynamicStore.securityProvider = nil
        return true
    }

    func unlockDataStore(key: ManagedKey) -> Bool {
//        guard self.keyMaker.validate(key: key) else {
//            return false
//        }
//
//        let securityProvider = MasterKeySecurityProvider(itemQueryProvider: self.itemQueryProvider, dataStore: self.securingDatastore.keyStore, key: key)
//        self.securingDatastore.masterDataStore.securityProvider = securityProvider
        return true
    }
}

@frozen public enum CryptorType: Int {
    case cryptKey = 0
    case sessionKey = 1
}

@frozen public enum ManagedKey {
    case cryptKey(Data)
    case biometricIDKey(Data)
    case sessionKey(Data)
    case escrowKeyInfo(Data)
    case deviceAuthenticationKey(Data)

    var count: Int {
        switch self {
        case .cryptKey(let cryptKey):
            return cryptKey.count

        case .biometricIDKey(let biometricIDKey):
            return biometricIDKey.count

        case .sessionKey(let sessionKey):
            return sessionKey.count

        case .escrowKeyInfo(let data):
            return data.count

        case .deviceAuthenticationKey(let deviceAuthKey):
            return deviceAuthKey.count
        }

    }

    // Warning: Never ever modify this to print the actual data. We never should be printing keys
    var info: String {
        switch self {
        case .cryptKey(let cryptKey):
            return "derived key, count = \(cryptKey.count)"

        case .biometricIDKey(let biometricIDKey):
            return "biometricAuthentication key, count = \(biometricIDKey.count)"

        case .sessionKey(let sessionKey):
            return "session key, count = \(sessionKey.count)"

        case .escrowKeyInfo(let data):
            return "escrow key, count = \(data.count)"

        case .deviceAuthenticationKey(let deviceAuthKey):
            return "device auth key, count = \(deviceAuthKey.count)"
        }
    }
}



class SDKManager {

    let appDataStore = AppDataStore()

    func startSDK() {
       // appDataStore.masterDataStore.securityProvider = nil
        appDataStore.applicationKey = "12345"
        // You can store item in dynamic store own provider
        appDataStore.dynamicStore.securityProvider = nil
        let lockDataStore =  ApplicationDataStoreLocker(dataStore: appDataStore)
        let status = lockDataStore.unlockDataStore(key: ManagedKey.biometricIDKey(Data()))
        if status {
            appDataStore.applicationKey = "12345"
        }
    }
}

/*

At the start of the SDK, we can create an application data store object.

The application data store can support various types of data storage, such as Plist store, file store, SQL store, KeyChain store, and more.

These storage options can be either secure or unsecured. For example, a store can be secured with a dynamic key or any other type of key.

When we create an instance of the ApplicationDataStore, it can load unsecured data stores and secure them with a dynamic key or another type of key. However, the master data will remain locked until we obtain the master key.

If the store is secure, like the master store, it will be locked with a key. This key can be generated using a username/password, passcode, random key, or a session with random data.

The master key can be generated randomly and encrypted based on the required key types, such as username/password, passcode, random key, session, random key, or biometrics, and then saved in the store.

To decrypt the key, we need one derived key from the authentication process, which can be the username/password, passcode, random key, session key, or stored under biometrics or device PIN.

Once we obtain the original master key by decrypting it using one of the available methods, we can unlock the data store with the master key.

The encrypted master key can be stored in a hardware secure space.

For forgotten passcode recovery, the master key is encrypted with an escrow key that is randomly generated. This encrypted key can be stored in the cloud. When the user authenticates correctly with their username and password, the server can provide the escrow key. By using the escrow key, we can retrieve the master key.

If Folio Settings are enabled in customer settings, we can create an application recovery key and save it. When a user switches accounts and we need to share data, we can decrypt the data using the recovery key. This use case is applicable.

 */
