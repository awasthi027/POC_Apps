//
//  YubiKeyConnectionViewModel.swift
//  CBAAuthentication
//
//  Created by Ashish Awasthi on 24/07/26.
//

import Foundation
import YubiKit

class YubiKeyConnectionViewModel: NSObject {
    // For now, we just save the connection data and clear it. There may be a need to have this in the future.
    /// NFC connection object
    var nfcConnection: YKFNFCConnection?
    /// MFI connection object
    var mfiConnection: YKFAccessoryConnection?
    /// Card connection object
    var cardConnection: YKFSmartCardConnection?
    /// Get connected accessory type
    var accessoryConnectionType: AccessoryConnectionType = .unknown
    /// We keep the singleton in a variable so we can change it for unit tests
    var ykManagerSingleton: YubiKitManager = YubiKitManager.shared
    /// Yubikey error object
    public var errorYubiKit: Error?
    /// Credential provider name
    public var credentialProviderName: String = "YubiKey"
    /// Accessory serial number
    public var yubiKeySerialNumber: Int32 = 0
    /// Accessory firmware version
    public var accessoryFirmwareVersion: String = ""
    /// Accessory connection Type MFI | NFC | Smart card
    public var connectedAccessoryType: AccessoryConnectionType = .unknown
    /// Start connection and Certificates set activation handler
    var activationHandler: ((YKFPIVSession?, Error?) -> Void)?
    /// connection failed retry time// Reset last connection will take time,
    static var retryAccessoryScanTime: CGFloat = 4.0

    // MARK: - YubiKey start connection Methods
    func startConnectionsAndGetAccessorySession(accessoryScanMessage: String = "Scan Your YubiKey",
                                                handler: @escaping (YKFPIVSession?, Error?) -> Void) {
        self.activationHandler = handler
        // reset the internal error member to the expected default
        self.errorYubiKit = nil

        // YubiKit does not actually use a completion handler for starting the connection.
        // It uses a delegate protocol. So we set this class as the delegate to get the notifications.
        ykManagerSingleton.delegate = self

        // Set the string displayed to the user.  If we don't set this, YubiKit will only have the english localization.
        YubiKitExternalLocalization.nfcScanAlertMessage = accessoryScanMessage

        // whoever completes first gets the connection
        // Start NFC first so the system "Ready to Scan" sheet appears when NFC is available.
        self.startConnectionNFC(isSupportNFCTags: YubiKitDeviceCapabilities.supportsISO7816NFCTags)
        self.startConnectionMFI(isSupportsMFIAccessoryKey: YubiKitDeviceCapabilities.supportsMFIAccessoryKey)
        self.startConnectionSmartCard(isSupportsSmartCardOverUSBC: YubiKitDeviceCapabilities.supportsSmartCardOverUSBC)

        // check that at least one of them started
        guard self.accessoryConnectionType != .unknown  else {
            // none of the connection types started, might be one of the few incompatible devices
            print("YubiKeyConnection:\(#function) for 'YubiKey' - no connection attempts have started, check which connection types are supported on this device")
            let theError = CBAError.YubiKeyUsage.notCompatible.nserror
            self.errorYubiKit = theError
            handler(nil, theError)
            return
        }
    }

    func startConnectionMFI(isSupportsMFIAccessoryKey: Bool) {
        print( "YubiKeyConnection: startConnectionMFI")

        guard isSupportsMFIAccessoryKey else {
            // MFI (Thunderbolt) not supported?  Maybe an iPad with USB-C?
            print("YubiKeyConnection: \(#function) for 'YubiKey' - YubiKit reports that MFI (thunderbolt) is not supported on this device")

            return
        }
        print( "YubiKeyConnection: YubiKit MFI Starting.")
        self.accessoryConnectionType = .mfi
        ykManagerSingleton.startAccessoryConnection()
        print("YubiKeyConnection: YubiKit MFI Started.")
    }

    func startConnectionSmartCard(isSupportsSmartCardOverUSBC: Bool) {
        print( "YubiKeyConnection: startConnectionSmartCard")

        guard isSupportsSmartCardOverUSBC, #available(iOS 16.0, *) else {
            // smartcard supported?  Maybe an iPad with USB-C?
            print( "CredentialActivation:\(#function) for 'YubiKey' - YubiKit reports that smart card interface is not supported on this device")
//            Dependencies.intelSdkHelper.leaveBreadcrumb("\(ashiIntelSDK.Userflow.activateCredentialYubiKey) - smart card interface not supported on this device.")
            return
        }
        print( "YubiKeyConnection: YubiKit Smart Card Starting.")
        self.accessoryConnectionType = .smartCard
        ykManagerSingleton.startSmartCardConnection()
    }

    func startConnectionNFC(isSupportNFCTags: Bool) {
        print( "YubiKeyConnection: startConnectionNFC")

        guard isSupportNFCTags else {
            print( "YubiKeyConnection: for 'YubiKey' - YubiKit reports that NFC is not supported on this device")
            return
        }

        print( "YubiKeyConnection: YubiKit NFC Starting.")
        // requires ios 13
        self.accessoryConnectionType = .nfc
        ykManagerSingleton.startNFCConnection()
        print( "YubiKeyConnection: YubiKit NFC Started.")
    }
}

// MARK: YubiKey connection callback methods
extension YubiKeyConnectionViewModel: YKFManagerDelegate {
    // NFC Connection callback methods
    func didConnectNFC(_ connection: YKFNFCConnection) {
        self.accessoryConnectionType = .nfc
        print( "YubiKeyConnection:\(#function) for '\(self.credentialProviderName)'")

        self.nfcConnection = connection
        self.nfcConnection?.pivSession({ pivSession, pivError in
            print(  "YubiKeyConnection: Reading NFC session")
            self.completeConnectionRequest(ykPIVSession: pivSession, error: pivError)
        })
        self.stopOtherConnections(accessoryConnectedType: .nfc)
        self.connectedAccessoryType = .nfc
    }

    func didDisconnectNFC(_ connection: YKFNFCConnection, error: Error?) {
        print( "YubiKeyConnection: \(#function) for '\(self.credentialProviderName)'")
        if let theError = error {
            print( "YubiKeyConnection: error=\(theError.localizedDescription)")
            if self.errorYubiKit == nil {
                // error not already reported
                self.completeConnectionRequest(ykPIVSession: nil, error: theError)
            }
        }
        self.stopOtherConnections(accessoryConnectedType: .unknown)
    }

    /// specific notes for didFailConnectingNFC() are in YubiKeyOperations
    func didFailConnectingNFC(_ error: Error) {
        // 'error' can be nil in YubiKit 4.2.0 due to a bug. See notes in YubiKeyOperations.

        // Determine if the failure actually happened within YubiKit or if it was
        // caused by us calling stopNFCConnection() when we connect to an MFI YubiKey.
        // We can remove this check once YubiKit releases a version with the fix for the bug in 4.2.0
        // If nfcStarted is true, YubiKit encountered an error and called directly here.
        // If nfcStarted is false, we called stopNFCConnection() where it was reset to false, which means we connected to an MFI YubiKey or had an error in earlier stages.
        // Note: We cannot just check 'error' for nil in release code. Swift warns that a check will always give the same value
        // due to the argument being marked as non-optional. Swift's optimizer will then remove the code block.

        print( "YubiKeyConnection: \(#function) for '\(self.credentialProviderName)' error=\(error.localizedDescription)")

        if self.errorYubiKit == nil {
            // error not already reported, Will set a breadcrumb
            self.completeConnectionRequest(ykPIVSession: nil, error: error)
        }
        self.stopOtherConnections(accessoryConnectedType: .unknown)
    }

    /// Smart Card Callback methods
    func didConnectSmartCard(_ connection: YKFSmartCardConnection) {
        // connected to smart card YubiKey
        self.accessoryConnectionType = .smartCard
        print( "YubiKeyConnection: Start Card Operation for '\(self.credentialProviderName)'")
       // Dependencies.intelSdkHelper.leaveBreadcrumb("\(ashiIntelSDK.Userflow.activateCredentialYubiKey) - Connected by TKSmartCard")
        self.cardConnection = connection

        print("YubiKeyConnection: \(#function) SUCCESS!!!! with card connection")

        self.cardConnection?.pivSession({ pivSession, pivError in
            print("YubiKeyConnection: \(#function) SUCCESS!!!! with smartcard PIV connection")
            self.completeConnectionRequest(ykPIVSession: pivSession, error: pivError)
        })
        self.stopOtherConnections(accessoryConnectedType: .smartCard)
        self.connectedAccessoryType = .smartCard
    }

    func didDisconnectSmartCard(_ connection: YKFSmartCardConnection, error: Error?) {
        print( "YubiKeyConnection: SmartCard Disconnection for '\(self.credentialProviderName)'")
        if let theError = error {
            print( "YubiKeyConnection: error=\(theError.localizedDescription)")
            if self.errorYubiKit == nil {
                // error not already reported
                // will set a breadcrumb
                self.completeConnectionRequest(ykPIVSession: nil, error: error)
            }
        }
        self.stopOtherConnections(accessoryConnectedType: .unknown)
    }

    /// Accessory Callback methods
    func didConnectAccessory(_ connection: YKFAccessoryConnection) {
        // Connected to MFI / Thunderbolt YubiKey
        self.accessoryConnectionType = .mfi
        print("YubiKeyConnection: \(#function) for '\(self.credentialProviderName)'")
        self.mfiConnection = connection
        self.mfiConnection?.pivSession({ pivSession, pivError in
            print("YubiKeyConnection: Reading accessory session")
            self.completeConnectionRequest(ykPIVSession: pivSession, error: pivError)
        })
        self.stopOtherConnections(accessoryConnectedType: .mfi)
        self.connectedAccessoryType = .mfi
    }

    /// didDisconnectAccessory() needs to be safe to call when didConnectAccessory() was not called.
    /// If stopAccessoryConnection() is called when there is no MFI connection, this delegate function may still be called.
    func didDisconnectAccessory(_ connection: YKFAccessoryConnection, error: Error?) {
        print( "YubiKeyConnection: \(#function) for '\(self.credentialProviderName)'")
        if let theError = error {
            print("YubiKeyConnection:  error=\(theError.localizedDescription)")
            if self.errorYubiKit == nil {
                // error not already reported, Will set a breadcrumb
                self.completeConnectionRequest(ykPIVSession: nil, error: theError)
            }
        }
        self.stopOtherConnections(accessoryConnectedType: .unknown)
    }
}

// MARK: - Utils Methods
extension YubiKeyConnectionViewModel {

    func readYubiKeySerialNumber(pivSession: YKFPIVSession,
                                 handler: @escaping (Int32, Error?) -> Void) {

        pivSession.getSerialNumber { serialNumber, error in
            if let serialError = error {
                print("YubiKeyConnection: PIV session attempt to get serial number gave error: \(serialError).")
                self.errorYubiKit = serialError
                handler(0, serialError)
                return
            }
            // serial number is possible PII, log in debug only
            print( "YubiKeyConnection: PIV session serial number: \(serialNumber).")
            handler(serialNumber, nil)
        }
    }

    func stopOtherConnections(accessoryConnectedType: AccessoryConnectionType) {
        switch accessoryConnectedType {
        case .mfi:
            if #available(iOS 16, *) {
                ykManagerSingleton.stopSmartCardConnection()
            }
            self.cardConnection = nil

            ykManagerSingleton.stopNFCConnection()
            self.nfcConnection = nil
            print( "YubiKeyConnection: Closing  NFC and Smart Card Connections")
        case .nfc:
            if #available(iOS 16, *) {
                ykManagerSingleton.stopSmartCardConnection()
            }
            self.cardConnection = nil

            ykManagerSingleton.stopAccessoryConnection()
            self.mfiConnection = nil
            print( "YubiKeyConnection: Closing  accessory and Smart Card Connections")
        case .smartCard:
            ykManagerSingleton.stopAccessoryConnection()
            self.mfiConnection = nil

            ykManagerSingleton.stopNFCConnection()
            self.nfcConnection = nil
            print( "YubiKeyConnection: Closing  accessory and NFC Connections")
        case .unknown:
            if #available(iOS 16, *) {
                ykManagerSingleton.stopSmartCardConnection()
            }
            self.cardConnection = nil

            ykManagerSingleton.stopAccessoryConnection()
            self.mfiConnection = nil

            ykManagerSingleton.stopNFCConnection()
            self.nfcConnection = nil
        }
    }

    /// Close all  type of connections, mfi, smartcard, nfc
    func shutdownYubiKit(isConnectionLost: Bool = false) {

//        YubiKitExternalLocalization.nfcScanSuccessAlertMessage = isConnectionLost ? "ashi.yubikey.operation.connectionIsLost.title".localizedString : "ashi.yubikey.nfcScanAlertMessage.success".localizedString
//        log(info: "YubiKeyConnection: Closing all types YubiKey Connections")
//        Dependencies.intelSdkHelper.leaveBreadcrumb("\(ashiIntelSDK.Userflow.activateCredentialYubiKey) - shutdown YubiKit connections.")
        self.stopOtherConnections(accessoryConnectedType: .unknown)
        ykManagerSingleton.delegate = nil
        self.accessoryConnectionType = .unknown
        self.activationHandler = nil
    }

    public func isConnectLostError(error: Error?) -> Bool {
        if let theError = error as NSError?,
           theError.code == YubiKeyUsageErrorCode.connectionLost.rawValue ||
            theError.code == YubiKeyUsageErrorCode.badCalculationResponse.rawValue {
            return true
        }
        return false
    }

    /// Convert slot Hex value into sting
    /// - Parameter slot: Accessory slot opcode
    /// - Returns: Return string value
    class func slotNumberToHex(slot: YKFPIVSlot) -> String {
        let stringResult = String(slot.rawValue, radix: 16, uppercase: false)
        return stringResult
    }

    /// Get slot name
    /// - Parameter slot: Accessory slot opcode
    /// - Returns: Return string value
    class func slotName(slot: YKFPIVSlot) -> String {
        var stringResult = "<error>"
        switch slot {
        case .authentication:
            stringResult = "Authentication"
        case .signature:
            stringResult = "Signature"
        case .keyManagement:
            stringResult = "Key Management"
        case .cardAuth:
            stringResult = "Card Auth"
        case .attestation:
            stringResult = "Attestation"
        default:
            stringResult = "Slot " + String(slot.rawValue, radix: 16, uppercase: false)
        }
        return stringResult
    }

    func completeConnectionRequest(ykPIVSession: YKFPIVSession?,
                                   error: Error?) {
        self.accessoryFirmwareVersion = ykPIVSession?.version.description ?? ""
        if let handler = self.activationHandler {
            handler(ykPIVSession, error)
            self.activationHandler = nil
        }
    }
}

import Foundation
import YubiKit

/// Represent error type.
protocol CBAErrorType: Error {
    var errorTitle: String { get }
    var errorCode: Int { get }
    var errorDomain: String { get }
    var errorUserInfo: [String: String]? {get}
    var nserror: NSError { get }
    var errorDescription: String? { get }
}

/// Abstract implementation
extension CBAErrorType {
    var errorTitle: String { return "ashi.alert.title.error" }
    var errorCode: Int { return _code }
    var errorDomain: String {return _domain}
    var errorUserInfo: [String: String]? {return nil}
    var nserror: NSError {
        return NSError(domain: errorDomain, code: errorCode, userInfo: errorUserInfo)
    }
    var errorDescription: String? { return String(describing: self) }
}

enum CBAError: CBAErrorType { }

/// ashi Error domains
final class CBAErrorDomains: NSObject {
    static let enrolmentError = "EnrolmentError"
    static let tokenOperationError = "TokenOperationError"
    static let yubiKeyOperationsError = "YubiKeyOperations"
    static let yubiKeyActivationError = "YubiKeyActivation"
    static let yubiKeyUsageError = "YubiKeyUsageError"
    static let yubiKeySessionError = YKFSessionErrorDomain      // from YubiKit/YKFSessionError.h
    static let policyRetriever = "PolicyRetrieverError"
    static let appstoreInfo = "AppstoreInfoFetchError"
}

import Foundation
import YubiKit

extension CBAError {

    // Common Yubikey errors. This are added to fix some critical code smells.
    static let yubikeyUnknownErrorString = "ashi.yubikey.operation.errorMessage.unknown"
    static let yubikeyNotActivatedErrorString = "ashi.yubikey.operation.errorMessage.notActivated"

    enum YubikeyActivation:  CBAErrorType {
        case unknown
        case noPIVSession
        case userCancelled
        case nfcStartError
        case duplicateCredential(_ details: [String: Any])
    }

    enum YubikeySession:  CBAErrorType {
        // Note: makes constants from YubiKit/YKFSessionError.h more usable, so these copy a few enum values.
        case connectionLost
        case timeout
        case missingCredentials
    }

    enum YubiKeyUsage:  CBAErrorType {
        case serialNotStored
        case serialMismatch            // current YubiKey serial number does not match the one used at activation time
        case notCompatible             // the YubiKit shows this device is not compatible, cannot start MFI or NFC connections
    }

    enum YubikeyOperation:  CBAErrorType {
        case unknown
        case serialNotStored
        case serialMismatch                     // current YubiKey serial number does not match the one used at activation time
        case notCompatible                      // the YubiKit shows this device is not compatible, cannot start MFI or NFC connections
        case invalidPIN(String? = nil)          // pin entered by user was invalid, maybe too short to be a real YubiKey PIN
        case activationNotFound                 // no YubiKey activation info was found
        case returnProblem                      // something did not get returned properly (like getting no error, but also no data)
        case tokenNotFound
        case slotNotFoundForToken               // mapping from token to YubiKey slot failed
        case pivSessionMissing(String? = nil)   // no error given, but no pivSession found
        case userCancelledError(String? = nil)
        case missingCertificate
        case expiredCertificate
    }
}

enum YubikeyActivationErrorCode: Int {
    // activation
    case unknown = 701
    case noPIVSession
    case userCancelled
    case nfcStartError
    case duplicateCredentials
}

enum YubikeySessionErrorCode: Int {
    // Note: in a previous version of YubiKit, we had trouble importing YubiKit/YKFSessionError.h, so we copied a few enum values.
    //  But this makes them more usable in our code, so we kept them after YubiKit upgrades enabled importing.
    case timeout = 1
    case connectionLost = 6         // value of YKFSessionErrorCode.connectionLost
    // although raw value of missingCredentials will be 7 initially
    // but the errorCode property will return YKFAPDUErrorCode.missingFile
    case missingCredentials

}

enum YubiKeyUsageErrorCode: Int {
    case serialNotStored = 801
    case serialMismatch
    case notCompatible
    /// Connection lost while performing yubiKey operations
    case connectionLost = 006
    /// connection lost while reading data from session
    case badCalculationResponse = 102
}

enum YubikeyOperationErrorCode: Int {
    case unknown = 901
    case serialNotStored
    case serialMismatch
    case notCompatible
    case invalidPIN
    case activationNotFound
    case returnProblem
    case tokenNotFound
    case slotNotFoundForToken
    case pivSessionMissing
    case userCancelledError
    case missingCertificate
    case expiredCertificate
}

extension  CBAError.YubikeyActivation: LocalizedError {
    var errorDomain: String {
        return CBAErrorDomains.yubiKeyActivationError
    }

    var errorCode: Int {
        switch self {
        case .unknown: return YubikeyActivationErrorCode.unknown.rawValue
        case .noPIVSession: return YubikeyActivationErrorCode.noPIVSession.rawValue
        case .userCancelled: return YubikeyActivationErrorCode.userCancelled.rawValue
        case .nfcStartError: return YubikeyActivationErrorCode.nfcStartError.rawValue
        case .duplicateCredential: return YubikeyActivationErrorCode.duplicateCredentials.rawValue
        }
    }

    var errorDescription: String? {
        return self.localizableInfo
    }

    var localizableInfo: String {
        switch self {
        case .unknown:
            return "ashi.yubikey.errorMessage.unknown"
        case .noPIVSession:
            return "ashi.yubikey.errorMessage.noPIVSession"
        case .userCancelled:
            return "ashi.yubikey.errorMessage.userCancelled"
        case .nfcStartError:
            return "ashi.yubikey.errorMessage.nfcError"
        case .duplicateCredential:
            return "ashi.duplicate.credentialSets.info.accessory.message"
        }
    }

    var userInfoDictionary: [String: Any] {
        switch self {
        case .unknown,
             .noPIVSession,
             .userCancelled,
             .nfcStartError:
            return [:]
          case .duplicateCredential(let detailsDictionary):
            return detailsDictionary
        }
    }
}

extension  CBAError.YubikeySession: LocalizedError {

    var errorDomain: String {

        return CBAErrorDomains.yubiKeySessionError
    }

    var errorCode: Int {
        switch self {
        case .timeout: return YubikeySessionErrorCode.timeout.rawValue
        case .connectionLost: return YubikeySessionErrorCode.connectionLost.rawValue
        case .missingCredentials: return Int(YKFAPDUErrorCode.missingFile.rawValue)
        }
    }

    var errorDescription: String? {
        return self.localizableInfo
    }

    var localizableInfo: String {
        switch self {
        case .timeout:
            return "ashi.yubikey.errorMessage.timeout"
        case .connectionLost:
            return "ashi.yubikey.errorMessage.sessionLost"
        case .missingCredentials:
            return "ashi.yubikey.errorMessage.missingCredentials"
        }
    }
}

extension  CBAError.YubiKeyUsage: LocalizedError {
    var errorDomain: String {
        return CBAErrorDomains.yubiKeyUsageError
    }

    var errorCode: Int {
        switch self {
        case .serialNotStored: return YubiKeyUsageErrorCode.serialNotStored.rawValue
        case .serialMismatch: return YubiKeyUsageErrorCode.serialMismatch.rawValue
        case .notCompatible: return YubiKeyUsageErrorCode.notCompatible.rawValue
        }
    }

    var errorDescription: String? {
        return self.localizableInfo
    }

    var localizableInfo: String {
        switch self {
        case .serialNotStored:
            return  CBAError.yubikeyNotActivatedErrorString
        case .serialMismatch:
            return "ashi.yubikey.errorMessage.wrongKey"
        case .notCompatible:
            return "ashi.yubikey.errorMessage.notCompatible"
        }
    }
}

extension  CBAError.YubikeyOperation: LocalizedError {
    var errorDomain: String {
        return CBAErrorDomains.yubiKeyOperationsError
    }

    var errorCode: Int {
        switch self {
        case .unknown: return YubikeyOperationErrorCode.unknown.rawValue
        case .serialNotStored: return YubikeyOperationErrorCode.serialNotStored.rawValue
        case .serialMismatch: return YubikeyOperationErrorCode.serialMismatch.rawValue
        case .notCompatible: return YubikeyOperationErrorCode.notCompatible.rawValue
        case .invalidPIN: return YubikeyOperationErrorCode.invalidPIN.rawValue
        case .activationNotFound: return YubikeyOperationErrorCode.activationNotFound.rawValue
        case .returnProblem: return YubikeyOperationErrorCode.returnProblem.rawValue
        case .tokenNotFound: return YubikeyOperationErrorCode.tokenNotFound.rawValue
        case .slotNotFoundForToken: return YubikeyOperationErrorCode.slotNotFoundForToken.rawValue
        case .pivSessionMissing: return YubikeyOperationErrorCode.pivSessionMissing.rawValue
        case .userCancelledError: return NSUserCancelledError
        case .missingCertificate: return YubikeyOperationErrorCode.missingCertificate.rawValue
        case .expiredCertificate: return YubikeyOperationErrorCode.expiredCertificate.rawValue
        }
    }

    var errorDescription: String? {
        return self.localizableInfo
    }

    var localizableInfo: String {
        switch self {
        case .unknown, .returnProblem:
            return  CBAError.yubikeyUnknownErrorString
        case .serialNotStored, .activationNotFound:
            return  CBAError.yubikeyNotActivatedErrorString
        case .serialMismatch:
            return "ashi.yubikey.errorMessage.wrongKey"
        case .notCompatible:
            return "ashi.yubikey.errorMessage.notCompatible"
        case .invalidPIN(let customMessage):
            if let message = customMessage  {
                return message
            }
            return CBAError.yubikeyUnknownErrorString
        case .tokenNotFound, .slotNotFoundForToken:
            return "ashi.yubikey.operation.errorMessage.slotNotFoundForCtkToken"
        case .pivSessionMissing(let customMessage):
            if let message = customMessage {
                return message
            }
            return CBAError.yubikeyUnknownErrorString
        case .userCancelledError(let customMessage):
            if let message = customMessage {
                return message
            }
            return "ashi.yubikey.operation.errorMessage.userCancelled"
        case .missingCertificate: return "ashi.yubikey.operation.errorMessage.missingCert"
        case .expiredCertificate: return "ashi.yubikey.operation.errorMessage.expiredCert"
        }
    }
}
