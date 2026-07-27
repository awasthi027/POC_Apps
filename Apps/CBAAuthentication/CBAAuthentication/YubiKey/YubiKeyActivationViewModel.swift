//
//  YubiKeyActivationViewModel.swift
//  CBAAuthentication
//
//  Created by Ashish Awasthi on 24/07/26.
//

import Foundation
import YubiKit


enum AccessoryConnectionType: Int, CustomStringConvertible {

    case unknown
    case mfi
    case smartCard
    case nfc

    var description: String {
        switch self {
        case .unknown: return "ashi.generic.unknown.title"
        case .mfi: return "ashi.yubikey.connection.mfi.title"
        case .smartCard: return "ashi.yubikey.connection.smartCard.title"
        case .nfc: return "ashi.yubikey.connection.nfc.title"
        }
    }
}

class YubiKeyActivationViewModel: NSObject {

    /// Start connection and Certificates set activation handler
    var activationHandler: (YKFPIVSession?, Error?) -> Void = { _, _ in /* It's optional call back */}
    /// ykConnection View Model
    private let ykConnectionViewModel: YubiKeyConnectionViewModel = YubiKeyConnectionViewModel()

    func startConnectionsAndGetAccessorySession(handler: @escaping (YKFPIVSession?, Error?) -> Void) {

        self.ykConnectionViewModel.startConnectionsAndGetAccessorySession { ykPIVSession, error in
            handler(ykPIVSession, error)
        }
    }

    // Common function to handle sessions and errors from both MFI and NFC
    func activateAccessoryCredential(pivSession: YKFPIVSession?, pivError: Error?,
                                     handler: @escaping(Bool, Error?) -> Void) {
         print("CredentialActivation: function completed with pivSession=\(String(describing: pivSession)), Error=\(String(describing: pivError))")
        guard pivError == nil else {
            let message = "CredentialActivation: Attempt to get PIV session gave error: \(pivError, default: "")."
            print("CredentialActivation: \(message)")
            // leave breadcrumb before reporting error to user so INTEL console has breadcrumbs in the correct order
           // Dependencies.intelSdkHelper.leaveBreadcrumb(ashiIntelSDK.Userflow.activateCredentialYubiKey + " - \(message)")
            self.ykConnectionViewModel.errorYubiKit = pivError
            handler(false, pivError)
            return
        }

        guard let pivSession = pivSession else {
            let message = "CredentialActivation: Unexpected error while starting PIV session with the YubiKey. pivSession was nil."
            print( message)
            // leave breadcrumb before reporting error to user so INTEL console has breadcrumbs in the correct order
           // Dependencies.intelSdkHelper.leaveBreadcrumb(ashiIntelSDK.Userflow.activateCredentialYubiKey + " - \(message)")
            // make our own error
            let theError = CBAError.YubikeyActivation.noPIVSession.nserror
            self.ykConnectionViewModel.errorYubiKit = theError
            handler(false, pivError)
            return
        }

        // note that the pivSession calls made here are executed in a serial operation queue (in YubiKit version 4.0.0)
        // note also, attempts to change nfcScanSuccessAlertMessage to something like 'Reading' did not work. The text did not appear.

        // Get Serial number so we can confirm interactions with the same key in the future.
        self.ykConnectionViewModel.readYubiKeySerialNumber(pivSession: pivSession) { serialNumber, _ in
            self.ykConnectionViewModel.yubiKeySerialNumber = serialNumber

            guard self.ykConnectionViewModel.errorYubiKit == nil else {
                // step encountered an error and processed it, abort the rest of the operations
                handler(false, self.ykConnectionViewModel.errorYubiKit)
                return
            }

            self.completeAccessoryCertificatesSetActivation(pivSession: pivSession) { isActivated in
                // make our own error
                if !isActivated {
                    if self.ykConnectionViewModel.errorYubiKit == nil {
                        let theError =  CBAError.YubikeySession.missingCredentials.nserror
                        self.ykConnectionViewModel.errorYubiKit = theError
                    }
                    handler(false, self.ykConnectionViewModel.errorYubiKit)
                } else {
                    handler(true, nil)
                }
            }
        }
    }

    // it may seem a little awkward to reduce the error handling of completion handlers into a function, but SonarQube was marking them as duplicated blocks
    // which made the quality gates fail.  So we have done this to satisfy the de-duplication requirement.
    func processGetCertResult(fromSlot: YKFPIVSlot,
                              cert: SecCertificate?,
                              error: Error?) -> SecCertificate? {
        guard error == nil else {
            // some other async step already encountered an error, just return nil
            // we check this here because all the async read operations are dispatched before any of them complete
            // only log in debug builds
            print( "CredentialActivation: PIV session certificate from slot \(YubiKeyConnectionViewModel.slotNumberToHex(slot: fromSlot)) '(\(YubiKeyConnectionViewModel.slotName(slot: fromSlot)))' - Another stage of activation already received an error. Skip processing ")
            return nil
        }

        if var pivError = error as NSError? {
            if pivError.code == YKFAPDUErrorCode.missingFile.rawValue {
                // PIV slot on YubiKey was empty, replace the YubiKit error with our own so user sees a meaningful message
                pivError = CBAError.YubikeySession.missingCredentials.nserror
            }
            print( "CredentialActivation: PIV session attempt to get certificate from slot \(YubiKeyConnectionViewModel.slotNumberToHex(slot: fromSlot)) '(\(YubiKeyConnectionViewModel.slotName(slot: fromSlot)))' gave error: \(pivError).")
            return nil
        }

        if cert == nil {
            print( "CredentialActivation: Error PIV session attempt to get certificate from slot\(YubiKeyConnectionViewModel.slotNumberToHex(slot: fromSlot)) '(\(YubiKeyConnectionViewModel.slotName(slot: fromSlot)))' returned nil.")
        } else {
            print( "CredentialActivation: PIV session attempt to get certificate succeeded for slot \(YubiKeyConnectionViewModel.slotNumberToHex(slot: fromSlot)) '(\(YubiKeyConnectionViewModel.slotName(slot: fromSlot)))'")
        }
        return cert
    }

    /// Check whether Accessory connection failed
    func isConnectionFailError(error: Error?) -> Bool {
       return self.ykConnectionViewModel.isConnectLostError(error: error)
    }

    /// Close all  type of connections, mfi, smartcard, nfc
    func shutdownYubiKit(isConnectionLost: Bool = false) {
        self.ykConnectionViewModel.shutdownYubiKit(isConnectionLost: isConnectionLost)
    }
    /// NFC connection object
    var nfcConnection: YKFNFCConnection? {
        return self.ykConnectionViewModel.nfcConnection
    }

    var errorYubiKit: Error? {
        return self.ykConnectionViewModel.errorYubiKit
    }

    func yubKeyConnectionError(error: Error?) {
        self.ykConnectionViewModel.errorYubiKit = error
    }
}

// MARK: Get certificate from PIVSession and create certificates sets
extension YubiKeyActivationViewModel {

    func getAccessoryCertificateFrom(slot: YKFPIVSlot,
                                     pivSession: YKFPIVSession,
                                     handler: @escaping(SecCertificate?) -> Void) {
        pivSession.getCertificateIn(slot) { (cert, error: Error?) in
            let secCert = self.processGetCertResult(fromSlot: slot,
                                                    cert: cert,
                                                    error: error)
            if let errorItem = error {
                self.ykConnectionViewModel.errorYubiKit = errorItem
            }
            handler(secCert)
        }
    }

    func completeAccessoryCertificatesSetActivation(pivSession: YKFPIVSession,
                                                    handler: @escaping(Bool) -> Void) {
        var oneCertMustBeAvailableToCreateSet = false
        let retrieveCertsGroup = DispatchGroup()

        // Get auth cert
        var authenticationCert: SecCertificate?
        retrieveCertsGroup.enter()
        self.getAccessoryCertificateFrom(slot: YKFPIVSlot.authentication,
                                         pivSession: pivSession) { authCert in
            authenticationCert = authCert
            if authCert != nil {
                oneCertMustBeAvailableToCreateSet = true
            }
            retrieveCertsGroup.leave()
            print("authenticationCert:\(oneCertMustBeAvailableToCreateSet)")
        }

        // Get signing cert
        var signingCert: SecCertificate?
        retrieveCertsGroup.enter()
        self.getAccessoryCertificateFrom(slot: YKFPIVSlot.signature,
                                         pivSession: pivSession) { signCert in
            signingCert = signCert
            if signCert != nil {
                oneCertMustBeAvailableToCreateSet = true
            }
            retrieveCertsGroup.leave()
            print("signingCert:\(oneCertMustBeAvailableToCreateSet)")
        }

        // Get encryption cert
        var encryptionCert: SecCertificate?
        retrieveCertsGroup.enter()
        self.getAccessoryCertificateFrom(slot: YKFPIVSlot.keyManagement,
                                         pivSession: pivSession) { encryCert in
            encryptionCert = encryCert
            if encryCert != nil {
                oneCertMustBeAvailableToCreateSet = true
            }
            retrieveCertsGroup.leave()
            print("encryptionCert:\(oneCertMustBeAvailableToCreateSet)")
        }

        retrieveCertsGroup.notify(queue: DispatchQueue.main, execute: {
            print( "CredentialActivation: \(#function) Finished all accessory certs requests")
            guard let cert = authenticationCert else {
                print( "CredentialActivation: \(#function) No crertificate.")
                return
            }
            let info = AccessoryCertsAndInfo()
            info.authenticationCert = SecCertificateCopyData(cert) as Data
            if let signingCert = signingCert {
                info.signingCert = SecCertificateCopyData(signingCert) as Data
            }
            if let encryptionCert = encryptionCert {
                info.encryptionCert = SecCertificateCopyData(encryptionCert) as Data
            }
            info.yubiKeySerialNumber = self.ykConnectionViewModel.yubiKeySerialNumber
            let certHash =  TokenPayload.certificateHash(cert)
            if !CTKManager.shared.isTokenPresentInCtkStore(tokenId: certHash ) {
                let isInstalled = CTKManager.shared.publishAccessoryCertificateToCTK(certificate: cert)
                print("isInstalled:\(isInstalled)")
            }
            handler(oneCertMustBeAvailableToCreateSet)
        })
    }
}

