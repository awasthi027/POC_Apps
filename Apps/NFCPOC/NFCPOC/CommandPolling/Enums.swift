//
//  Enums.swift
//  NFCPOC
//
//  Created by Ashish Awasthi on 20/10/23.
//

import Foundation

enum SessionErrorCode: Int {

    /*! When the key didn't repond to an issued command. In such a scenario the key may not be properly connected
     to the device or the communication with the key is somehow broken along the SDK-IAP2-Firmware path. In such
     a scenario replugging or checking if the key is properly connected may solve the issue.
     */
    case readTimeoutCode = 0x000001

    /*! When the library cannot write/send a command to the key. In such a scenario the key may not be properly connected
     to the device or the communication with the key is somehow broken along the SDK-IAP2-Firmware path. In such
     a scenario replugging or checking if the key is properly connected may solve the issue.
     */
     case writeTimeoutCode = 0x000002

    /*! When the key expects the user to confirm the presence by touching the key. The user didn't touch the key
     for 15 seconds so the operation was canceled.
     */
      case touchTimeoutCode = 0x000003

    /*! A request to the key cannot be performed because the key is performing another operation.
     @discussion
        This should not be an issue when using only YubiKit because YubiKit will execute the requests sequentially. This issue
        may happen when the key is performing an operation on behalf of another application or if the user is generating an OTP
        which is independent of YubiKit. The key operations are usually fast so a recovery solution is to try again in a few seconds.
     */
           case keyBusyCode = 0x000004

    /*! A certain key application is missing or it was disabled using a configuration tool like YubiKey Manager. In such a scenario
     the functionality of the key should be enabled before trying again the request.
     */
        case missingApplicationCode = 0x000005

    /*! A request to the key cannot be performed because the connection was lost
     (e.g. Tag was lost when key was taken away from NFC reader)
     */
    case connectionLost = 0x000006

    /*! A request to the key cannot be performed because the connection was not found
     */
     case noConnection = 0x000007

    /*! A request to the key returned an unexpected result
     */
    case nexpectedStatusCode = 0x000008

    /*! Invalid session state. This can be caused by another session connecting to the Yubkey or stale stored state.
     */
    case innvalidSessionStateStatusCode = 0x000009
};


/*!
 @abstract
    Reffers to the encoding type of APDU as defined in ISO/IEC 7816-4 standard.
 */
enum APDUType: Int {
    /*!
     Data does not exceed 256 bytes in length. CCID commands usually are encoded with short APDUs.
     */
    case short
    /*!
     Data exceeds 256 bytes in length. Some YubiKey applications (like U2F) use extended APDUs.
     */
    case extended
}
