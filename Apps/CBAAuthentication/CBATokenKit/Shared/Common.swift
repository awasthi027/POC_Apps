//
//  Common.swift
//  CBAAuthentication
//
//  Created by Ashish Awasthi on 24/07/26.
//

struct CBAConstants {
    static let appGroupIdentifier = "group.ashi.cbaauth"

    public static let thalesAllowedPayloadInQrCode = 3

    public static let keyLocalNotificationOpenApp = "keyLocalNotificationOpenApp"

    public static let localNotificationKeyOperationType = "localNotificationKey_Operation_Type"

    public static let keyHSMOperations               = "HSMOperation"
    public static let keyHSMOperationID              = "HSMOperationID"
    public static let keyHSMOperationType            = "HSMOperationType"
    public static let keyHSMOperationTypeSign        = "HSMOperationSign"
    public static let keyHSMOperationTypeAuthorize   = "HSMOperationAuthorize"
    public static let keyHSMOperationTypeDecrypt     = "HSMOperationDecrypt"
    public static let keyHSMOperationInput           = "HSMOperationInput"
    public static let keyHSMOperationAlgorithm       = "HSMOperationAlgorithm"
    public static let keyHSMOperationTokenID         = "HSMOperationTokenID"
    public static let keyHSMOperationState           = "HSMOperationState"
    public static let keyHSMOperationStartTime       = "HSMOperationStartTime"
    public static let keyHSMOperationExpireTime      = "HSMOperationExpireTime"
    public static let keyHSMOperationBeginUptime     = "HSMOperationBeginUptime"

    public static let keyHSMOperationOutput          = "HSMOperationOutput"
    public static let keyHSMOperationError           = "HSMOperationError"

    public static let keyHSMOperationFlagKey         = "HSMOperationFlagKey"     // Defaults entry used to signal to the extension

    public enum HSMOperationState: String {
        case start
        case working    // read the operation and began working - prevents doing it more than once
        case finish     // ended successfully
        case error      // ended with error
    }
    
    public static let kYubiKeyMinPINLength: Int = 6
    
    public enum HSMOperationType: String {
        case sign
        case decrypt
        case authorize
        case unknown
    }
}
