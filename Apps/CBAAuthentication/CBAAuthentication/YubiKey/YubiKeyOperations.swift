//
//  YubiKeyOperations.swift
//  CBAAuthentication
//
//  Created by Ashish Awasthi on 24/07/26.
//

import Foundation
import YubiKit
// for error constants
import CoreNFC

/// YubiKey operation complete handler Example: Signing or Decryption, Authentication not supporting yet
public typealias YubiKeyOperationHandler = (Data?, Error?) -> Void

/// Accessory operation information, which is needed to perform operation
class AccessoryOperationInfo {
    public var yubiKeySlot: YKFPIVSlot
    /// Accessory serial number
    public var serialNumber: Int32
    /// Accessory sec key algorithm
    public var secKeyAlgorithm: SecKeyAlgorithm
    /// Accessory PIN
    public var pin: String = ""
    /// Credential set activation timestamp,
    var timeStamp: Double = 0.0

    init(yubiKeySlot: YKFPIVSlot,
         serialNumber: Int32,
         secKeyAlgorithm: SecKeyAlgorithm,
         timeStamp: Double = 0.0,
         pin: String = "") {
        self.yubiKeySlot = yubiKeySlot
        self.serialNumber = serialNumber
        self.timeStamp = timeStamp
        self.pin = pin
        self.secKeyAlgorithm = secKeyAlgorithm
    }
    /// request data, it's optional
    var requestData: Data?

}

class YubiKeyOperations: NSObject {
    /// YubiKey connection or operation error, Its optional, default value nil
    public var errorYubiKit: Error?
    /// Maximum yubikey PIN retry count, default value is 3
    public var pinTriesRemaining: Int32 = 3 // default value
    /// Credential provider name,  default YubiKey
    public var credentialProviderName = "Yubikey"
    /// Minimum YubiKey PIN lenth   default YubiKey is 6
    public let minYubiKeyPINLength: Int = CBAConstants.kYubiKeyMinPINLength
    /// YubiKey connection viewModel object
    let viewModel = YubiKeyConnectionViewModel()
    /// Start connection handler, default value is nil
    var pivOperationHandler: ((YKFPIVSession?, Error?) -> Void)?

    // MARK: - Dependency Injection
    // we keep the singleton in a variable so we can change it for unit tests
    var ykManagerSingleton = YubiKitManager.shared
    /// shared default
    var sharedDefaults: UserDefaults = YubiKeyOperations.setupDefaults()
    /// Remember accessory for retry operation
    var accessoryInfo: AccessoryOperationInfo?
    /// YubiKey request backhandler
    var yubiKeyOperationHandler: YubiKeyOperationHandler?
    /// default accessory connection message
    private var defaultAccessoryScanMessage: String = "Scan Your YubiKey";

    // Must be a class function since it will be used to initialize an instance
    class func setupDefaults(suiteName: String = CBAConstants.appGroupIdentifier) -> UserDefaults {
        guard let theDefaults = UserDefaults(suiteName: suiteName) else {
            print("YubiKeyOperations: The shared defaults is not available. Using standard defaults. CTK token jobs will not function.")
            return UserDefaults.standard
        }
        return theDefaults
    }

    // MARK: - YubiKey operation
    // This function needs the completions handler to pass errors back to the caller.
    // Since the checks are done here, this is where the appropriate Error objects can be created.
    func preProcessChecksPassed(accessorySerialNumber: Int32) -> (isCheckPassed: Bool, error: Error?) {

//        guard AccessoryCertificateSet.isAcessoryCertificatesSetActivated(providerTag: .yubiKey) else {
//            print("YubiKeyOperations: App was not activated with YubiKey.")
//            self.errorYubiKit = CBAError.YubikeyOperation.activationNotFound.nserror
//            return (false, self.errorYubiKit)
//        }

        if accessorySerialNumber == 0 {
            print("YubiKeyOperations: App was not activated with YubiKey.")
            self.errorYubiKit = CBAError.YubikeyOperation.serialNotStored.nserror
            return (false, self.errorYubiKit)
        }
        return (true, nil)
    }

    /// Call this function to have the user prompted for the YubiKey PIN, then sign the data with that PIN
    /// Stage 1 of a usual sign operation
    func promptForPinAndSign(dataToSign: Data,
              accessoryOpInfo: AccessoryOperationInfo,
            handler: @escaping YubiKeyOperationHandler) {
        self.yubiKeyOperationHandler = handler
        self.accessoryInfo = accessoryOpInfo
        let operationName = "sign"
        let result = self.preProcessChecksPassed(accessorySerialNumber: accessoryOpInfo.serialNumber)
        guard result.isCheckPassed else {
            handler(nil, result.error)
            return
        }
        self.promptForAccessoryPIN { (userCancelled: Bool, accessoryPin: String) in
            print( "YubiKeyOperations: promptForAccessoryPIN finished with userCancelled=\(userCancelled)")
            if self.handlePromptErrors(userCancelled: userCancelled,
                                       pinString: accessoryPin,
                                       operationName: operationName,
                                       handler: handler) {
                // completion was called in handlePromptErrors() where it creates Error objects
                return
            }
            accessoryOpInfo.pin = accessoryPin
            self.sign(dataToSign: dataToSign,
                      accessoryOpInfo: accessoryOpInfo,
                      handler: handler)
        }
    }

    // Use this function to sign data if you already have the PIN. Use the other version of the sign function if you need to get the PIN.
    // Stage 2 of a usual sign operation
    func sign(dataToSign: Data,
              accessoryOpInfo: AccessoryOperationInfo,
              handler: @escaping YubiKeyOperationHandler) {
        self.accessoryInfo = accessoryOpInfo
        self.accessoryInfo?.requestData = dataToSign
        self.yubiKeyOperationHandler = handler
        print("YubiKeyOperations: \(#function) with dataToSign size \(dataToSign.count) algorithm: \(accessoryOpInfo.secKeyAlgorithm)")
        // start the connection to the YubiKey
        self.startConnectionAndValidateAccessorySession { pivSession, _ in
            if let yubiKeySession = pivSession {
                self.pivSign(dataToSign: dataToSign,
                             accessoryOpInfo: accessoryOpInfo,
                             pivSession: yubiKeySession,
                             handler: handler)
            } else {
                handler(nil, self.errorYubiKit)
            }
        }
    }

    // We have the PIV Session, now we can get the serial number from YubiKey and validate it.
    // Stage 3 of a usual sign operation
    // Note that we do not allow default slot values for the deeper internal sign functions. The slot should have been decided by this point.
    internal func pivSign(dataToSign: Data,
                          accessoryOpInfo: AccessoryOperationInfo,
                          pivSession: YKFPIVSession,
                          handler: @escaping YubiKeyOperationHandler) {
        self.yubiKeyOperationHandler = handler
        self.validateCertificate(pivSession: pivSession,
                                        accessoryOpInfo: accessoryOpInfo) { isCertAvailable, error in
            print( "YubiKeyOperations: Cert on Slot: \(accessoryOpInfo.yubiKeySlot), status: \(isCertAvailable)")
            if isCertAvailable {
                self.serialNumberFromAccessorySession(pivSession: pivSession,
                                             accessorySerialNumber: accessoryOpInfo.serialNumber) { isSerialMatching, error in
                    print("YubiKeyOperations: Start Signing operation.")
                    if isSerialMatching {
                        // serial is the same, continue signing
                        self.pivSignYubiKey(dataToSign: dataToSign,
                                            accessoryOpInfo: accessoryOpInfo,
                                            withPIVSession: pivSession,
                                            handler: handler)
                    } else {
                        self.handlerYubiKeyOperationError(error: error,
                                                          result: nil,
                                                          yubiKeyOperation: .sign)
                    }
                }
            } else {
                self.handlerYubiKeyOperationError(error: error,
                                                  result: nil,
                                                  yubiKeyOperation: .sign)
            }
        }
    }

    // Now we can actually sign the data with the YubiKey
    // Stage 4 of a usual sign operation
    internal func pivSignYubiKey(dataToSign: Data,
                                 accessoryOpInfo: AccessoryOperationInfo,
                                 withPIVSession pivSession: YKFPIVSession,
                                 handler: @escaping YubiKeyOperationHandler) {
        // NOTE: if you want to update the signing credentials saved during activation,
        // consider getting the certificate before starting the verify and sign operations.
        // In testing, more operations inside the verifyPin completion handler has caused some of them to fail,
        // including the sign operation.

        // NOTE: be careful with how much you try to do in the verifyPin() completion handler, or in the pivSession in general. If it times out, the operations remaining might fail.
        self.accessoryInfo = accessoryOpInfo
        self.yubiKeyOperationHandler = handler
        self.verifyAccessoryPIN(pivSession: pivSession, userEnterPIN: accessoryOpInfo.pin) { isVerified, _ in
            print("YubiKeyOperations: PIV session attempt to verify PIN succeeded. Tries remaining: \(self.pinTriesRemaining)")
            print("YubiKeyOperations: Sign PIN verification status")
            if isVerified {
                let keyType = YKFPIVKeyType.RSA2048
                let keyTypeString = String(keyType.rawValue, radix: 16, uppercase: true)

                // let theAlgorithm = SecKeyAlgorithm.rsaSignatureMessagePKCS1v15SHA256   // 256 suggested by PSPDFKit email, 512 was used in their sample app
                let theAlgorithm = accessoryOpInfo.secKeyAlgorithm

                // sign the data with the private key in the slot  (needs verifyPin)
                print("YubiKeyOperations: signWithKey start. slot=\(YubiKeyConnectionViewModel.slotNumberToHex(slot: accessoryOpInfo.yubiKeySlot))")
                print( "YubiKeyOperations: keytype = \(keyTypeString), algorithm='\(theAlgorithm)', dataToSign size=\(dataToSign.count)")

                pivSession.signWithKey(in: accessoryOpInfo.yubiKeySlot, type: keyType, algorithm: theAlgorithm, message: dataToSign) { (resultData, resultError) in
                    print( "YubiKeyOperations signWithKey completion. resultData is \(resultData==nil ? "nil" : "SET"), Error= \(String(describing: resultError?.localizedDescription))" )
                    self.handlerYubiKeyOperationError(error: resultError,
                                                      result: resultData,
                                                      yubiKeyOperation: .sign)
                }
            } else {
                handler(nil, self.errorYubiKit)
            }
        }
    }

    // Use this version if you need to prompt the user for the PIN before the operation
    internal func promptForPinAndDecrypt(dataToDecrypt: Data,
                                         accessoryOpInfo: AccessoryOperationInfo,
                                         handler: @escaping YubiKeyOperationHandler) {
        let operationName = "decrypt"
        let result = self.preProcessChecksPassed(accessorySerialNumber: accessoryOpInfo.serialNumber)
        guard result.isCheckPassed else {
            handler(nil, result.error)
            return
        }
        self.promptForAccessoryPIN { (userCancelled: Bool, accessoryPIN: String) in
            print("YubiKeyOperations: promptForAccessoryPIN completed with userCancelled=\(userCancelled), pinString:\(accessoryPIN.count) chars")

            if self.handlePromptErrors(userCancelled: userCancelled, pinString: accessoryPIN, operationName: operationName, handler: handler) {
                // completion was called in handlePromptErrors() where it creates Error objects
                return
            }
            accessoryOpInfo.pin = accessoryPIN
            self.ashiecrypt(dataToDecrypt: dataToDecrypt,
                            accessoryOpInfo: accessoryOpInfo,
                            handler: handler)
        }

    }

    // stage 2: when you have the PIN, start the connection and get the pivSession
    internal func ashiecrypt(dataToDecrypt: Data,
                             accessoryOpInfo: AccessoryOperationInfo,
                             handler: @escaping YubiKeyOperationHandler) {
        self.accessoryInfo = accessoryOpInfo
        self.accessoryInfo?.requestData = dataToDecrypt
        self.yubiKeyOperationHandler = handler
        print( "YubiKeyOperations: decrypt: data of size \(dataToDecrypt.count) algorithm: \(accessoryOpInfo.secKeyAlgorithm)")
        // Start the connection to the YubiKey
        self.startConnectionAndValidateAccessorySession { pivSession, _ in
            if let yubiKeySession = pivSession {
                // We have the PIV Session, now we can go to the next step.
                self.ashiecryptSerial(dataToDecrypt: dataToDecrypt,
                                      accessoryOpInfo: accessoryOpInfo,
                                      pivSession: yubiKeySession,
                                      handler: handler)
            } else {
                handler(nil, self.errorYubiKit)
            }
        }
    }

    // We have the PIV Session, now we can get the serial number from YubiKey and validate it.
    // Stage 3 of a usual decrypt operation
    internal func ashiecryptSerial(dataToDecrypt: Data,
                                   accessoryOpInfo: AccessoryOperationInfo,
                                   pivSession: YKFPIVSession,
                                   handler: @escaping YubiKeyOperationHandler) {
        self.yubiKeyOperationHandler = handler
        self.validateCertificate(pivSession: pivSession,
                                        accessoryOpInfo: accessoryOpInfo,
                                        toValidateExpireCert: false) { isCertAvailable, error in
            print( "YubiKeyOperations: Cert on Slot: \(accessoryOpInfo.yubiKeySlot), status: \(isCertAvailable)")
            if isCertAvailable {
                self.serialNumberFromAccessorySession(pivSession: pivSession,
                                                      accessorySerialNumber: accessoryOpInfo.serialNumber) { isSerialNumberMatching, error in
                    if isSerialNumberMatching {
                        print( "YubiKeyOperations: Start decrypt operation.")
                        // serial is the same, continue operation
                        self.ashiecrypt(dataToDecrypt: dataToDecrypt,
                                        accessoryOpInfo: accessoryOpInfo,
                                        pivSession: pivSession,
                                        handler: handler)
                    } else {
                        handler(nil, error)
                    }
                }
            } else {
                self.handlerYubiKeyOperationError(error: error,
                                                  result: nil,
                                                  yubiKeyOperation: .decrypt)
            }
        }
    }

    // stage 4: when you have the PIN and the pivSession and the serial number
    internal func ashiecrypt(dataToDecrypt: Data,
                             accessoryOpInfo: AccessoryOperationInfo,
                             pivSession: YKFPIVSession,
                             handler: @escaping YubiKeyOperationHandler) {
        // NOTE: it is possible the credentials have changed since activation. We do not currently attempt to update them during operations.

        // NOTE: be careful with how much you try to do in the verifyPin() completion handler, or in the pivSession in general. If it times out, the operations remaining might fail.
        self.yubiKeyOperationHandler = handler
        self.verifyAccessoryPIN(pivSession: pivSession, userEnterPIN: accessoryOpInfo.pin) { isVerified, error in
            print("YubiKeyOperations: PIV session attempt to verify PIN succeeded. Tries remaining: \(self.pinTriesRemaining)")
            print("YubiKeyOperations: PIN Verification status: \(isVerified)")
            if isVerified {
                let keyType = YKFPIVKeyType.RSA2048
                let keyTypeString = String(keyType.rawValue, radix: 16, uppercase: true)

                let theAlgorithm = SecKeyAlgorithm.rsaSignatureMessagePKCS1v15SHA512   // 256 suggested by PSPDFKit email, 512 was used in their sample app

                // sign the data with the private key in the slot  (needs verifyPin)
                print("YubiKeyOperations: decrypt start. slot=\(YubiKeyConnectionViewModel.slotNumberToHex(slot: accessoryOpInfo.yubiKeySlot))")
                print("YubiKeyOperations: keytype = \(keyTypeString), algorithm='\(theAlgorithm)', dataToDecrypt has size=\(dataToDecrypt.count)")

                pivSession.decryptWithKey(in: accessoryOpInfo.yubiKeySlot,
                                          algorithm: accessoryOpInfo.secKeyAlgorithm,
                                          encrypted: dataToDecrypt) { (resultData, resultError) in
                    print("YubiKeyOperations: decrypt completion. resultData is \(resultData==nil ? "nil" : "SET"), Error= \(String(describing: resultError?.localizedDescription))" )
                    self.handlerYubiKeyOperationError(error: resultError,
                                                      result: resultData,
                                                      yubiKeyOperation: .decrypt)
                }
            } else {
                handler(nil, error)
            }
        }
    }

    /**
    common code for handling the possible errors from the prompt
    - Parameter userCancelled: the userCancelled argument from the prompt completion
    - Parameter pinString: the pinString argument from the prompt completion
    - Parameter operationName: for logging and error strings, the one-word name of the operation, like 'decrypt', 'sign', 'authentication'
    - Parameter promptCompletion: completion handler from the calling function
    - Returns: true if there was a problem and the completion was called,
               false if there was no problem and operation should continue
    */
    internal func handlePromptErrors(userCancelled: Bool,
                                     pinString: String, operationName: String,
                                     handler: @escaping YubiKeyOperationHandler) -> Bool {
        self.yubiKeyOperationHandler = handler
        guard !userCancelled else {
            // User hit 'cancel' on the PIN prompt
            // add INTELSDK breadcrumbs
            let message = "\(operationName): cancelled by user"
            print("YubiKeyOperations: OperationName: \(message)")
            self.errorYubiKit = CBAError.YubikeyOperation.userCancelledError(message).nserror
            // YubiKey not started, no need to shut it down before calling completion
            handler(nil, self.errorYubiKit)

            // No need to call showErrorAlert(). The user knows they tapped 'Cancel'.
            return true
        }

        // If we figure out how to detect cases where minimum length of key pin is different than 6, we need to handle that.
        guard pinString.count >= self.minYubiKeyPINLength else {
            // add INTELSDK breadcrumbs
            let message = "YubiKeyOperations: \(operationName): user entered invalid PIN"
            print("\(message)")

            let ashierror = CBAError.YubikeyOperation.invalidPIN(message)
            self.handlerYubiKeyOperationError(error: ashierror,
                                              result: nil,
                                              yubiKeyOperation: .unknown)
            return true
        }

        return false
    }

    func startConnectionAndValidateAccessorySession(handler: @escaping(YKFPIVSession?, Error?) -> Void) {
        self.viewModel.startConnectionsAndGetAccessorySession(accessoryScanMessage: self.defaultAccessoryScanMessage) { pivSession, theError in
            self.validateSession(pivSession: pivSession, theError: theError, handler: handler)
        }
    }

    func validateSession(pivSession: YKFPIVSession?,
                         theError: Error?,
                         handler: @escaping(YKFPIVSession?, Error?) -> Void) {
        guard theError == nil else {
            print("YubiKeyOperations: startConnectionAndValidateAccessorySession Error= \(theError)" )
            // YubiKey not started, no need to shut it down before calling completion
            self.errorYubiKit = theError
            handler(nil, self.errorYubiKit)

            if !self.isUserCancelledError(error: theError) {
                // not a user-cancelled situation, show an error
                var descriptionLocalized = CBAError.YubikeyOperation.unknown.localizableInfo
                if let nsError = theError as NSError?, nsError.domain == NFCErrorDomain {
                    // it was actually an NFC error, get the description from the NFC utility
                   // descriptionLocalized = NFCUtility.descriptionForAppleNFCError(error: nsError)
                }
                // call showErrorAlert() after signCompletion() in case the error alert is needed above the Back-To-App view
                self.showErrorAlert(alertMessage: descriptionLocalized)
            }
            return
        }
        guard let pivSession = pivSession else {
            print( "YubiKeyOperations: startConnectionAndValidateAccessorySession thePivSession = nil" )
            // YubiKey not started, no need to shut it down before calling completion
            self.handlerYubiKeyOperationError(error: CBAError.YubikeyOperation.pivSessionMissing().nserror,
                                              result: nil,
                                              yubiKeyOperation: .unknown)
            return
        }
        handler(pivSession, nil)
    }

    // MARK: - UI
    /// call completion with either userCancelled = true and empty string, or userCancelled = false and the PIN string
    func promptForAccessoryPIN (promptCompletion: @escaping (_ userCancelled: Bool, _ pinString: String) -> Void ) {
        // map to the class version
        YubiKeyOperations.promptForAccessoryPIN(minYubiKeyPINLength: self.minYubiKeyPINLength, promptCompletion: promptCompletion)
    }

    // For this class version, we added a minYubiKeyPINLength argument because there is no class variable to hold it.
    class func promptForAccessoryPIN (minYubiKeyPINLength: Int = CBAConstants.kYubiKeyMinPINLength,
                                      promptCompletion: @escaping (_ userCancelled: Bool, _ pinString: String) -> Void ) {

        print("YubiKeyOperations: PromptForAccessoryPIN BEGIN")
        DispatchQueue.main.async {
            guard let appDelegate = self.presenter else {
                print("YubiKeyOperations: Failed to retrieve Application Delegate, unable to show PIN prompt.")
                return
            }

            let alertTitle = "Unlock Accessory"
            let alert = UIAlertController.init(title: alertTitle, message: "", preferredStyle: UIAlertController.Style.alert)

            // Field for user to type PIN
            alert.addTextField { (textField: UITextField) in
                textField.placeholder = "YubiKey PIN"
                textField.isSecureTextEntry = true
                textField.keyboardType = UIKeyboardType.decimalPad
            }
            // CANCEL
            alert.addAction(UIAlertAction(title: "cancel", style: UIAlertAction.Style.cancel, handler: { (_: UIAlertAction) in
                print( "YubiKeyOperations: User cancelled PIN")
                promptCompletion(true, "")    // empty pin string for this case
            }))
            // OK
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: { (_: UIAlertAction) in
                print( "YubiKeyOperations: User gave a PIN")
                let pinTextField = alert.textFields?.first
                let pinString = pinTextField?.text

                guard let thePinString = pinString, thePinString.count >= minYubiKeyPINLength else {
                    print( "YubiKeyOperations: Error User entered invalid pin. (too short)")
                    let alertMessageFormat = "ashi.yubikey.pin.tooShortMinLength.text.(%d)"
                    let alertMessage = String(format: alertMessageFormat, arguments: [minYubiKeyPINLength])

                    promptCompletion(true, "")   // respond as if user cancelled

                    // call showErrorAlert() after the completion handler in case the error alert is needed above the Back-To-App view
                    self.showErrorAlert(alertMessage: alertMessage)
                    return
                }

                promptCompletion(false, thePinString)

            }))
        appDelegate.rootViewController?.present(alert, animated: true, completion: nil)

        }
        print( "YubiKeyOperations: PromptForAccessoryPIN  END")
    }

    // MARK: - Custom
    func showErrorAlert(alertTitle: String = "ashi.alert.title.error",
                        alertMessage: String) {
        // instance version, map to class function
        YubiKeyOperations.showErrorAlert(alertTitle: alertTitle, alertMessage: alertMessage)
    }

    /// present a UIAlert with the text arguments
    class func showErrorAlert(alertTitle: String = "ashi.alert.title.error", alertMessage: String ) {

        print("YubiKeyOperations: \(#function) BEGIN with title='\(alertTitle)', message='\(alertMessage)'")

        let alertOKAction = UIAlertAction(title: "ashi.alert.action.title.ok", style: UIAlertAction.Style.default,
                                          handler: { (_: UIAlertAction) in
            print( "YubiKeyOperations: COMPLETE: User clicked OK button on error alert")
            // add INTELSDK breadcrumbs
        })
//        Dependencies.ashiAppPresenter?.displayAlertMessage(title: alertTitle,
//                                                           message: alertMessage, actions: [alertOKAction])
    }

    func isUserCancelledError(error: Error? ) -> Bool {
        guard let nsError = error as NSError? else {
            return false
        }
        if nsError.domain == NFCErrorDomain,
           nsError.code == NFCReaderError.readerSessionInvalidationErrorUserCanceled.rawValue {
            // the CoreNFC error for 'user cancelled'
            return true
        }

        return false
    }

    func verifyAccessoryPIN(pivSession: YKFPIVSession,
                            userEnterPIN: String,
                            completeHandler: @escaping(Bool, Error?) -> Void) {

        pivSession.verifyPin(userEnterPIN) { triesRemaining, operationError in
            // YubiKit docs say this handler is called on a background worker thread
            self.pinTriesRemaining = triesRemaining // will be the max if verify was successful
            guard operationError == nil else {
                print("YubiKeyOperations: PIV session attempt to verify PIN failed. Tries remaining: \(triesRemaining) Error:\(operationError)")
                var alertMessage = ""
                if triesRemaining == 0 {
                    // no more retries, PIN reset required
                    alertMessage = "ashi.yubikey.pin.reset.text"
                } else {
                    // some tries remaining, incorrect PIN error
                    let alertMessageFormat = "ashi.yubikey.incorrectPinRemainingTries.text.(%d)"
                    alertMessage = String(format: alertMessageFormat, arguments: [triesRemaining])
                }
                // set errorYubiKit before calling shutdownYubiKit() so that function can change the YubiKit screen message
                self.errorYubiKit = operationError
                completeHandler(false, self.errorYubiKit)
                // done with YubiKey
                self.shutdownYubiKit()
                // call showErrorAlert() after the completion so a Back-to-App view will appear under the error alert
                self.showErrorAlert(alertMessage: alertMessage)

                return
            }
            completeHandler(true, operationError)
        }
    }

    func serialNumberFromAccessorySession(pivSession: YKFPIVSession,
                               accessorySerialNumber: Int32,
                               completeHandler: @escaping(Bool, Error?) -> Void) {

        pivSession.getSerialNumber { (sessionSerialNumber: Int32, error: Error?) in
            guard error == nil else {
                print("YubiKeyOperations: PIV session attempt to get YubiKey serial number gave error: \(error).")
                self.handlerYubiKeyOperationError(error: error,
                                                  result: nil,
                                                  yubiKeyOperation: .unknown)
                return
            }

            // compare serial numbers
            guard accessorySerialNumber == sessionSerialNumber else {
                // This YubiKey is NOT the one used for activation
                // serial number is possible PII so we do not log it (except in debug builds)
                print("YubiKeyOperations: Attempt to sign with different YubiKey than used for activation, aborting operation.")
                print("YubiKeyOperations: Accessory serialNo=\(accessorySerialNumber) Session serialNo=\(sessionSerialNumber)")
                // make our own error
                let ashiError  = CBAError.YubikeyOperation.serialMismatch
                self.handlerYubiKeyOperationError(error: ashiError,
                                                  result: nil,
                                                  yubiKeyOperation: .unknown)
                return

            }
            print("PIV session serial number: \(sessionSerialNumber).")           // serial number is possible PII, log in debug only
            print("YubiKeyOperations: Confirmed this YubiKey is the one used for activation.")
            completeHandler(true, error)
        }
    }

    /// Before performing operation check whether certificate is availale on selected certificate slot
    /// - Parameters:
    ///   - pivSession: pivSession object
    ///   - accessoryOpInfo: operation inputs details
    ///   - completeHandler: completeHandler(true/false, error is optional)
    func validateCertificate(pivSession: YKFPIVSession,
                                             accessoryOpInfo: AccessoryOperationInfo,
                                             toValidateExpireCert: Bool = true,
                                             completeHandler: @escaping(Bool, Error?) -> Void) {
       let activationViewModel = YubiKeyActivationViewModel()
       activationViewModel.getAccessoryCertificateFrom(slot: accessoryOpInfo.yubiKeySlot,
                                             pivSession: pivSession) { secCertificate in

           var isValidCert: Bool = true
           if secCertificate == nil,
                let error = activationViewModel.errorYubiKit {
               completeHandler(isValidCert, error)
               return
           }
           var ashiError = CBAError.YubikeyOperation.tokenNotFound
//           if let p12Data = secCertificate {
//               if let cert = ashiCertificate(certificateData: SecCertificateCopyData(p12Data) as Data),
//                  (CertificateUtility.certificateExpiryStatus(certificate: cert.x509) != .expired
//                   || !toValidateExpireCert) {
//                   isValidCert = true
//               } else {
//                   ashiError = CBAError.YubikeyOperation.expiredCertificate
//               }
//           } else {
//               ashiError = CBAError.YubikeyOperation.missingCertificate
//           }
           if isValidCert {
               completeHandler(isValidCert, nil)
           } else {
               completeHandler(isValidCert, ashiError)
           }
       }
   }

    /// Shutdown YubiKey
    func shutdownYubiKit(isConnectionLost: Bool = false) {
        self.viewModel.shutdownYubiKit(isConnectionLost: isConnectionLost)
    }
}

extension YubiKeyOperations {
    class var presenter: UIWindow? {
        guard let anchor = ForegroundWindowLocator.activeKeyWindow() else {
           print("Cannot start ASWebAuthenticationSession: no foreground-active UIWindowScene. Bring app to foreground and retry.")
            return nil
        }
        return anchor
    }
}

// MARK: Utils methods
extension YubiKeyOperations {

    /// Complete PIV request operation session
    func completePIVRequestOperation(ykPIVsession: YKFPIVSession?,
                                     error: Error?) {
        if let handler = self.pivOperationHandler {
            handler(ykPIVsession, error)
        }
        print("YubiKeyOperations: Error \(error)")
        // prevent acc   print(identally calling this twice due to the way YubiKit 4.0.0 handles didConnect/didDisconnect delegate calls
        self.pivOperationHandler = nil
    }

    func handlerYubiKeyOperationError(error: Error?,
                                      result: Data?,
                                      yubiKeyOperation: CBAConstants.HSMOperationType) {
        self.viewModel.errorYubiKit = error
        self.errorYubiKit = error
        let isConnectLost = self.viewModel.isConnectLostError(error: error)
        self.shutdownYubiKit(isConnectionLost: isConnectLost)
        guard let handler = self.yubiKeyOperationHandler  else {
            print("ConnectionLostError: Missing YubiKey request handler")
            return
        }

        if isConnectLost,
           let accessoryInfo = self.accessoryInfo,
           let requestData = accessoryInfo.requestData {
            // Set the string displayed to the user.  If we don't set this, YubiKit will only have the english localization.
            self.defaultAccessoryScanMessage = "Failed to Scan. Hold your Yubikey near your Device and try scanning again."
            print( "ConnectionLostError: Waiting for resign")
            // Waiting to dismiss existing NFC Scan sheet and then present
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + YubiKeyConnectionViewModel.retryAccessoryScanTime) {
            print("ConnectionLostError: Resign called Operation Type: \(yubiKeyOperation.rawValue)")
                switch yubiKeyOperation {
                case .sign:
                    self.sign(dataToSign: requestData,
                              accessoryOpInfo: accessoryInfo,
                              handler: handler)
                case .decrypt:
                    self.ashiecrypt(dataToDecrypt: requestData,
                                    accessoryOpInfo: accessoryInfo,
                                    handler: handler)
                case .unknown, .authorize:
                    print("ConnectionLostError: No need to perform any operation.")
                }
            }
        } else {
            if let resultItem = result,
               error == nil {
                          print( "YubiKeyOperations: Completed Operation Success")
                // Update last YubiKey key communication type in activated credentail set
               // self.updateLastAccessoryCommunicationTypeInCredentialSet(timestamp: self.accessoryInfo?.timeStamp ?? 0.0)
                handler(resultItem, self.errorYubiKit)
            } else {
                var message = CBAError.YubikeyOperation.unknown.localizableInfo
                if let errorItem = error as?  CBAError.YubikeyOperation {
                                    print( "YubiKeyOperations: Completed operation with Error: \(errorItem.localizableInfo)")
                    message = errorItem.localizableInfo
                }
                self.showErrorAlert(alertMessage: message)
                handler(nil, self.errorYubiKit)
            }
        }
    }

//    func updateLastAccessoryCommunicationTypeInCredentialSet(timestamp: Double) {
//
//        print( "YubiKeyOperations: Updating Accessory connection Type Credential Set Timestamp: \(timestamp)")
//        let credentialSets = AccessoryCertificateSet.listOfAccessoryCertificatesSets(providerTag: .yubiKey)
//        for item in credentialSets {
//            if item.timestamp == timestamp {
//                            print( "YubiKeyOperations: ConnectionType OLD: \(item.connectionType), NEW: \(self.viewModel.connectedAccessoryType)")
//                item.connectionType = self.viewModel.connectedAccessoryType.rawValue
//                let status = AccessoryCertificateSet.updatedCertificatesSetsList(accessoryCertificateSet: credentialSets)
//                print("YubiKeyOperations: Update Status: \(status)")
//                break
//            }
//        }
//    }
}



