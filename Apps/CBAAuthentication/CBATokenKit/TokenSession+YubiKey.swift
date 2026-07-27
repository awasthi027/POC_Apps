//
//  TokenSession+YubiKey.swift
//  CBAAuthentication
//
//  Created by Ashish Awasthi on 24/07/26.
//

import Foundation
import UserNotifications

import CryptoTokenKit

enum TokenOperation: String, CustomStringConvertible {
    case sign
    case decrypt
    case auth
    case keyExchange

    var description: String {
        switch self {
        case .sign:
            return "Sign"
        case .decrypt:
            return "Decrypt"
        case .auth:
            return "Auth"
        case .keyExchange:
            return "Key Exchange"
        }
    }
}
/// ashiTokenError in case of error in CTK extension.
enum CBATokenError {

    case featureNotImplemented(operation: TokenOperation)
    case incorrectKeyUsage(certName: String, operation: TokenOperation)
    case algorithmNotSupported(algorithm: String)
    case tokenNotFound(certName: String)
    case decryptionFailure(OSStatus)
    case signingFailure(OSStatus)
    case privateKeyNotFound(OSStatus)
    case extensionTimeOut
    case certificateNotFound
    case correspondingSecKeyAlgorithmNotFound
    case sharedSpaceError

    /// Error code
    private var tkErrorCode: TKError.Code {
        switch self {
        case .featureNotImplemented:
            return .notImplemented
        case .extensionTimeOut:
            return .communicationError
        case .tokenNotFound, .privateKeyNotFound:
            return .tokenNotFound
        default:
            return .badParameter
        }
    }
    /// This error be recieved by consumer application in case of any error.
    var error: NSError {
        return NSError(domain: TKErrorDomain, code: self.tkErrorCode.rawValue, userInfo: [:])
    }
}
/// This Swift code extends our TokenSession class to interface to YubiKey in the main PIV-D application.

extension TokenSession {
    func signWithYubiKey(dataToSign: Data, algorithm: SecKeyAlgorithm, keyObjectID: String) throws -> Data {
        let operationID = "SignData_" + UUID().uuidString     // use a GUID to prevent possible overlapping operations
        // Prompt user to tap banner so PIV-D can finish signing the data
        let notificationTitle = "CBAAuthentication App"
        let notificationSubtitle = "Tap here to authenticate with a certificate from your accessory."

        let ykResultData = try self.setupYubiKeyInteraction(inputData: dataToSign,
                                                            algorithm: algorithm,
                                                            keyObjectID: keyObjectID,
                                                            operationID: operationID,
                                                            nTitle: notificationTitle,
                                                            nSubTitle: notificationSubtitle)

        return ykResultData
    }

    fileprivate func setupYubiKeyInteraction(inputData: Data, algorithm: SecKeyAlgorithm, keyObjectID: String, operationID: String, nTitle: String, nSubTitle: String) throws -> Data {
        // setup shared container user defaults
        guard let sharedDefaults = UserDefaults(suiteName: CBAConstants.appGroupIdentifier) else {
            throw CBATokenError.sharedSpaceError.error
        }

        // delete any old result flag
        sharedDefaults.removeObject(forKey: operationID)

        // remove any old operation data
        JobDataUtil.clearFromSharedDefaults()

        // create operation data
        let resultYubiKeyJobData = TokenKeyJobData(algorithm: algorithm, inputData: inputData, id: operationID, tokenID: keyObjectID, finishedFlagKey: operationID)
        JobDataUtil.writeToDefaults(jobData: resultYubiKeyJobData)

        // post local notification to take the user to ashi app
        self.postNotificationToSwitchToApp(nTitle: nTitle, nSubTitle: nSubTitle)

        // There is no asynchronous option for a token extension. Once we exit, it is over, so we wait.
        if waitTimedOut(afterSeconds: 60, sharedDefaults: sharedDefaults, finishedFlagKey: operationID) {
            // we timed out
            throw CBATokenError.extensionTimeOut.error
        }

        // remove the flag entry (will be hard to find later without the GUID)
        sharedDefaults.removeObject(forKey: operationID)

        // read operations object from user defaults
        guard let returnedYubiKeyJobData = JobDataUtil.readFromSharedDefaults() else {
            throw CBATokenError.sharedSpaceError.error
        }

        // check if it had an internal error
        if let theError = returnedYubiKeyJobData.error {
            throw theError
        }

        guard let ykResultData = returnedYubiKeyJobData.outputData else {
            // we established there was no error, so there should be data, it must be a communication error
            throw CBATokenError.sharedSpaceError.error
        }
        return ykResultData
    }

    func postNotificationToSwitchToApp(nTitle: String, nSubTitle: String) {
        // setup local notification to take the user to ashi app
        let content = UNMutableNotificationContent()
        content.title = nTitle
        content.body = nSubTitle
        content.sound = UNNotificationSound.default
        // build notification userInfo with minimal data to say notification is just meant to bring ashi to the foreground.
        content.userInfo = [CBAConstants.keyLocalNotificationOpenApp: CBAConstants.keyLocalNotificationOpenApp] as [String: Any]

        let localNotifTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)

        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content,
                                            trigger: localNotifTrigger)

        UNUserNotificationCenter.current().add(request) { error in
            if error != nil {
                // nothing we can do from here.  we can't log from within the extension
            }
        }
    }

    /// Waits until either the finishedFlagKey is found in the shared user defaults or we time out.
    /// Returns true if the operation timed out. Returns false if a result was returned.
    func waitTimedOut(afterSeconds: Int, sharedDefaults: UserDefaults, finishedFlagKey: String) -> Bool {
        // Use the forward-only DispatchTime (uptime counter) to check the timeout.  Date() is subject to sudden time updates, especially if this triggers the radios for the first time in a while.
        let timeoutTime = DispatchTime.now() + DispatchTimeInterval.seconds(afterSeconds)

        // Wait loop - wait until we timeout or have a result
        // We cannot just stop for a long period like with a semaphore or cross-process communications.
        // The iOS might detect that nothing is executing inside the token extension, and kill the extension.

        // We must simply loop in short periods until either we timeout or receive a result (operation result or error)

        let sleepTime: TimeInterval = 0.5
        while true {
            Thread.sleep(forTimeInterval: sleepTime)    // regular sleep() can't go below 1 second

            // check for the result being returned from the ashi app
            if sharedDefaults.object(forKey: finishedFlagKey) != nil {
                return false
            }

            // check for timeout condition
            if DispatchTime.now() >= timeoutTime {
                return true
            }
        }
    }
}
