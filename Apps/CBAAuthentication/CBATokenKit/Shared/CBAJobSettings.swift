//
//  CBAJobSettings.swift
//  CBAAuthentication
//
//  Created by Ashish Awasthi on 24/07/26.
//

import Foundation

private protocol AnyOptional {
    var isNil: Bool { get }
}

extension Optional: AnyOptional {
    var isNil: Bool { self == nil }
}


@propertyWrapper
struct Persist<Value> {
    let key: String
    let defaultValue: Value
    let store: CBAStore

    init(key: String, defaultValue: Value, ashiStore: CBAStore = UserDefaultsStore()) {
        self.key = key
        self.defaultValue = defaultValue
        self.store = ashiStore
    }

    var wrappedValue: Value {
        get {
            let value = store.object(for: key) as? Value
            return value ?? defaultValue
        }
        set {
            if let optional = newValue as? AnyOptional, optional.isNil {
                store.removeObject(for: key)
            } else {
                store.set(object: newValue, for: key)
            }
        }
    }
}

@objc protocol CBAStore {
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

class UserDefaultsStore: CBAStore {

    var userDefaults: UserDefaults? = .standard

    /// Instantiates UserDefaultsStore
    /// - Parameters:
    ///   - type: Specify it to be standard or shared.
    ///   - suiteName: custom suitename can be provided, escpecially for tests.
    init(type: UserDefaultsType = .standard, suiteName: String = CBAConstants.appGroupIdentifier) {
        self.userDefaults = (type == .shared) ? UserDefaults(suiteName: suiteName) : UserDefaults.standard
    }

    func object(for key: String) -> Any? {
        return self.userDefaults?.object(forKey: key)
    }

    func set(object: Any, for key: String) {
        self.userDefaults?.set(object, forKey: key)
    }

    func removeObject(for key: String) {
        self.userDefaults?.removeObject(forKey: key)
    }
}
// Be careful when importing frameworks.  This is used by the token extension, which restricts what can be used.

protocol JobSettings {
    var jobData: Data? { get set }
}

class CBAJobSettings: JobSettings {
    static let shared = CBAJobSettings()
    @Persist(key: CBAConstants.keyHSMOperations, defaultValue: nil, ashiStore: UserDefaultsStore(type: .shared))
    var jobData: Data?
}

/* Purpose:
 This class exists for 2-way communications between the token extension and the app.
 Apple requires that token extensions have no interaction with UIKit. (No UI is allowed.)
 This No-UI restriction means this class cannot be combined with the code in the app which will interact with Key provider.
    For eg: The YubiKey interactions require UI for things like prompting the user to connect a YubiKey or to enter a PIN.
 Apple also restricts the communications between the token extension and app, limiting it to files in the shared container for the app group.
 Thus, this class focuses only on communications via the shared app group user defaults.
 Token Extension to App
    - gathers the information required to perform the needed interactions or operations with the Yubikey.
 App to Token Extension
    This class contains information needed by the token extension at the conclusion of the interaction.
    This class also has a function to signal from the app to the token extension that the operation has concluded. This could be done by altering values within the class data, but that would require some complex code within the token extension.
        For now, we signal by just setting another user defaults entry. The key of this entry is specified by the token extension when setting up the data.
            The absence of the entry in user defaults indicates the job is not finished.
            The presence of the entry in user defaults indicates the job is finished.

 Since communication between the token extension and app relies on the user to bring the app to the foreground, the communication is unreliable.
 The app may find the job data waiting from a long time ago, which should no longer be processed.  So a function is provided for the app's convenience to make the decision.

 NOTE: there is also no access to the WS One SDK logging functions from the token extension. Since this file must be used by both app and token extension, there is no logging in this file.
 */

class TokenKeyJobData: NSObject, NSSecureCoding {

    var algorithm: SecKeyAlgorithm
    var state: CBAConstants.HSMOperationState = CBAConstants.HSMOperationState.start
    var tokenID: String
    var id: String
    var startDate: Date = Date()
    var timeoutDate: Date = Date().addingTimeInterval(60.0)            // calculate expire time
    var inputData: Data
    var finishedDefaultsKey: String     // user defaults key to use to signal completion to the extension (alternate: derive from ID)

    // App -> Token Extension information
    var outputData: Data?
    var error: NSError?

    init(algorithm: SecKeyAlgorithm, inputData: Data, id: String, tokenID: String, finishedFlagKey: String ) {
        self.algorithm = algorithm
        self.inputData = inputData
        self.id = id
        self.tokenID = tokenID
        self.finishedDefaultsKey = finishedFlagKey
    }

    // MARK: - NSSecureCoding

    static var supportsSecureCoding: Bool = true

    func encode(with coder: NSCoder) {
        coder.encode(self.algorithm.rawValue, forKey: CBAConstants.keyHSMOperationAlgorithm)
        coder.encode(self.inputData, forKey: CBAConstants.keyHSMOperationInput)
        coder.encode(self.state.rawValue, forKey: CBAConstants.keyHSMOperationState)
        coder.encode(self.tokenID, forKey: CBAConstants.keyHSMOperationTokenID)
        coder.encode(self.id, forKey: CBAConstants.keyHSMOperationID)
        coder.encode(self.startDate, forKey: CBAConstants.keyHSMOperationStartTime)
        coder.encode(self.timeoutDate, forKey: CBAConstants.keyHSMOperationExpireTime)

        coder.encode(self.finishedDefaultsKey, forKey: CBAConstants.keyHSMOperationFlagKey)
        coder.encode(self.outputData, forKey: CBAConstants.keyHSMOperationOutput)
        coder.encode(self.error, forKey: CBAConstants.keyHSMOperationError)
    }

    required init?(coder: NSCoder) // NS_DESIGNATED_INITIALIZER
    {
        guard
              let theAlgorithmRaw   = coder.decodeObject(forKey: CBAConstants.keyHSMOperationAlgorithm) as? String,
              let theStateString    = coder.decodeObject(forKey: CBAConstants.keyHSMOperationState) as? String,
              let theState          = CBAConstants.HSMOperationState(rawValue: theStateString),
              let theInputData      = coder.decodeObject(forKey: CBAConstants.keyHSMOperationInput) as? Data,
              let theTokenID        = coder.decodeObject(forKey: CBAConstants.keyHSMOperationTokenID) as? String,
              let theID             = coder.decodeObject(forKey: CBAConstants.keyHSMOperationID) as? String,
              let theStartDate      = coder.decodeObject(forKey: CBAConstants.keyHSMOperationStartTime) as? Date,
              let theTimeoutDate    = coder.decodeObject(forKey: CBAConstants.keyHSMOperationExpireTime) as? Date,
              let theFlagKey        = coder.decodeObject(forKey: CBAConstants.keyHSMOperationFlagKey) as? String
        else {
            return nil
        }

        // these can be nil or not encoded
        let theOutputData     = coder.decodeObject(forKey: CBAConstants.keyHSMOperationOutput) as? Data
        let theError          = coder.decodeObject(forKey: CBAConstants.keyHSMOperationError) as? NSError

        self.algorithm = SecKeyAlgorithm(rawValue: theAlgorithmRaw as CFString)
        self.state = theState
        self.tokenID = theTokenID
        self.id = theID
        self.startDate = theStartDate
        self.timeoutDate = theTimeoutDate

        self.inputData = theInputData

        self.finishedDefaultsKey = theFlagKey
        self.error = theError
        self.outputData = theOutputData
    }

    // MARK: - validation
    func shouldBeProcessed() -> Bool {
        // NOTE: this class is used in our token extension, so does not have access to log

        guard self.state == CBAConstants.HSMOperationState.start else {
            // state shows this has already started or already finished
            return false
        }

        guard Date() < self.timeoutDate else {
            // current time is after timeout, this job is too old, do not process it
            return false
        }

        guard !self.finishedDefaultsKey.isEmpty else {
            // without this key, there is no way to signal to the consumer that job is completed
            return false
        }

        guard !self.inputData.isEmpty else {
            // there is no input data to process
            return false
        }

        guard !self.tokenID.isEmpty else {
            // there is no token ID to process into a slot, nothing we can do
            return false
        }

        return true
    }
}
