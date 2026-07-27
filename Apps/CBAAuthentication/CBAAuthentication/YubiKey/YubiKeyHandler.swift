//
//  YubiKeyHandler.swift
//  CBAAuthentication
//
//  Created by Ashish Awasthi on 24/07/26.
//


import Foundation
import YubiKit

protocol AbstractJobHandler {
    var suiteName: String { get set }
    func handleIncomingJobOperation(jobData: TokenKeyJobData, suiteName: String, forcePinPrompt: Bool)
    func processResult(jobData: TokenKeyJobData, suiteName: String, description: String, resultData: Data?, error: Error?)
    func handleDecryptJobOperation(jobData: TokenKeyJobData)
    func handleAuthorizeJobOperation(jobData: TokenKeyJobData)
    func handleSignJobOperation(jobData: TokenKeyJobData)
    func handleJobOperationError(jobData: TokenKeyJobData, error: Error?)
}
extension AbstractJobHandler {
    var suiteName: String {
        get { return CBAConstants.appGroupIdentifier}
        set { }
    }

    func handleIncomingJobOperation(jobData: TokenKeyJobData,
                                    suiteName: String = CBAConstants.appGroupIdentifier,
                                    forcePinPrompt: Bool = false) {
        handleIncomingJobOperation(jobData: jobData, suiteName: suiteName, forcePinPrompt: forcePinPrompt)
    }

    func processResult(jobData: TokenKeyJobData, suiteName: String = CBAConstants.appGroupIdentifier, description: String, resultData: Data?, error: Error?) {
        if let outputData = resultData, error == nil {
            // save signed blob back to user defaults
            jobData.outputData = outputData
            jobData.state = .finish
            JobDataUtil.writeToDefaults(jobData: jobData)
            JobDataUtil.setFinishedFlag(flagName: jobData.finishedDefaultsKey, suiteName: suiteName)       // alert the token extension that the operation is complete

            // show the 'return' view controller
            // this handle operation could be called on a background thread, so dispatch to main queue for UIKit calls
//            DispatchQueue.main.async {
//                presenter?.presentBackToAppInstructionsVC()
//            }
            print("YubiKeyJob: Completed Request Succefully")
            print("YubiKeyHandler: \(description): succeeded!")
        } else {
            handleJobOperationError(jobData: jobData, error: error)
        }
    }
}
/// This class is responsible for determining if a YubiKey interaction is needed and triggering the interactions.

class YubiKeyHandler: AbstractJobHandler {
    func handleDecryptJobOperation(jobData: TokenKeyJobData) {

    }

    var ykOperations: YubiKeyOperations = YubiKeyOperations()
    // yubikeySlot will be set in handleYubiKeyOperation method, But for tests if we want to test Sign or Decrypt operation for specific slot, we can set and use it.
    var yubikeySlot: YKFPIVSlot = .signature
    /// Certificate Credential Set
   // var certificateCredentialSet: AccessoryCertificateSet?

    /// This function is called to check for any incoming operations.
    /// If there are any, it will trigger the needed steps.
    func handleIncomingJobOperation(jobData: TokenKeyJobData, suiteName: String, forcePinPrompt: Bool) {
        print("YubiKeyHandler: Detected job waiting from token extension.")

        // check it is still valid to be processed
        guard jobData.shouldBeProcessed() else {
            return
        }
        // is YubiKey activated?
        // can't process if not activated - delete
//        guard AccessoryCertificateSet.isAcessoryCertificatesSetActivated(providerTag: .yubiKey) else {
//            log(error: "YubiKeyHandler: Cannot process detected job from token extension. YubiKey is not activated.")
//            return
//        }

        // handle it
        self.handleYubiKeyOperation(ykJobData: jobData, suiteName: suiteName)
    }

    func handleYubiKeyOperation( ykJobData: TokenKeyJobData, suiteName: String = CBAConstants.appGroupIdentifier) {
        print( "YubiKeyHandler: handling job with ID = \(ykJobData.id)")

        ykJobData.state = .working    // prevent any other launch from starting this
        JobDataUtil.writeToDefaults(jobData: ykJobData)     // save the change back to defaults

        // determine which certificate matches the chosen token and which slot on the YubiKey it came from
//        guard let result = self.tokenIdToSlot(tokenID: ykJobData.tokenID),
//              let yubikeySlot = YKFPIVSlot.init(rawValue: result.certificaterSlot) else {
//            print( "Persistent token ID did not map to a slot")
//            let theError = CBAError.YubikeyOperation.slotNotFoundForToken
//            ykJobData.error = theError.nserror
//            ykJobData.outputData = nil
//            ykJobData.state = .error
//            JobDataUtil.writeToDefaults(jobData: ykJobData)     // save the change back to defaults
//            JobDataUtil.setFinishedFlag(flagName: ykJobData.finishedDefaultsKey, suiteName: self.suiteName)       // alert the token extension that the operation is complete
//            return
//        }

        // Updating certificate slot and accessory serial number
        self.yubikeySlot = YKFPIVSlot.authentication
       // self.certificateCredentialSet = result.credentialSet

         self.handleSignJobOperation(jobData: ykJobData)

    }

//    var presenter: Presenter? {
//        return ashiUtil.appDelegate
//    }

    func handleAuthorizeJobOperation(jobData: TokenKeyJobData) {
        print("YubiKeyHandler:on slot:\(yubikeySlot). Aborting.")
    }

    func handleSignJobOperation(jobData: TokenKeyJobData) {
        // no need to log the job type, it must be YubiKey type because we are in the YubiKeyHandler
        print( "YubiKeyHandler: using slot=\(YubiKeyConnectionViewModel.slotNumberToHex(slot: yubikeySlot)) aka \(YubiKeyConnectionViewModel.slotName(slot: yubikeySlot)), withAlgorithm:\(jobData.algorithm), for tokenID=\(jobData.tokenID)")

        let accessoryCertsAndInfo = AccessoryCertsAndInfo()
        // use the ykOperations version that will prompt for the pin
        let accessoryOpInfo = AccessoryOperationInfo.init(yubiKeySlot: yubikeySlot,
                                                          serialNumber: accessoryCertsAndInfo.yubiKeySerialNumber,
                                                          secKeyAlgorithm: jobData.algorithm,
                                                          timeStamp: 0.0)
        self.ykOperations.promptForPinAndSign(dataToSign: jobData.inputData, accessoryOpInfo: accessoryOpInfo) { resultData, error in
            self.processResult(jobData: jobData, suiteName: self.suiteName, description: "Sign", resultData: resultData, error: error)
        }
    }

    func handleJobOperationError(jobData: TokenKeyJobData, error: Error?) {
        let theError = CBAError.YubikeyOperation.unknown
        let error = (error != nil) ? error : theError

        let errorString = String(describing: error)

        jobData.error = error as NSError?
        jobData.outputData = nil
        jobData.state = .error
        JobDataUtil.writeToDefaults(jobData: jobData)
        JobDataUtil.setFinishedFlag(flagName: jobData.finishedDefaultsKey, suiteName: suiteName)       // alert the token extension that the operation is complete
//        ensureOnMainQueue {
//            self.presenter?.presentBackToAppInstructionsVC()    // show the 'return' view controller
//        }
    }
}


