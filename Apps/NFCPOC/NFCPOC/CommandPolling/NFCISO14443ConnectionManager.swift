//
//  NFCISO14443ConnectionManager.swift
//  NFCPOC
//
//  Created by Ashish Awasthi on 20/10/23.
//

import Foundation
import Foundation
import CoreNFC

enum NFCConnectionState: Int {
    /// The session is closed. No commands can be sent to the key.
    case closed
    /// The session is in an intermediary state between closed and opened. Before the tag was discovered.
    /// The application should not send commands to the key when the session is in this state.
    case polling
    /// The session is opened and ready to use. The application can send immediately commands to the key.
    case open
}

protocol NFCPollingConnectionCallBack: NSObjectProtocol {
    func didConnectNFC(manager: NFCISO14443ConnectionManager,
                       connectionState: NFCConnectionState,
                       error: String)
}

class NFCISO14443ConnectionManager: NSObject, ObservableObject {


     var nfcTagReaderSession: NFCTagReaderSession?
     var connectionState: NFCConnectionState = .closed
     var delegate: NFCPollingConnectionCallBack?
     var iso7816NfcTagAvailabilityTimer: Timer?
     var tagDescription: NFCTagDescription?
     var connectionController: NFCConnectionController?
     var communicateQueue: OperationQueue?
     var sharedDispatchQueue: DispatchQueue?

    func startSession() {
        self.setupCommunicationQueue()
//        guard let tagSession = self.nfcTagReaderSession,  tagSession.isReady else {
//            debugPrint("NFC session already started. Ignoring start request.");
//            return
//        }
        let localReaderSession = NFCTagReaderSession(pollingOption: .iso14443, delegate: self, queue: nil)
        localReaderSession?.alertMessage = "Hold your iPhone near the item to learn more about it."
        localReaderSession?.begin()
    }

    func setupCommunicationQueue() {
        self.communicateQueue = OperationQueue()
        self.communicateQueue?.maxConcurrentOperationCount = 1
        let concurrentQueue = DispatchQueue(label: "queuename", attributes: .concurrent)
        self.sharedDispatchQueue = concurrentQueue
    }

}

extension NFCISO14443ConnectionManager: NFCTagReaderSessionDelegate {

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        debugPrint("NFC session did become active.");
        self.nfcTagReaderSession = session;
        //[self updateServicesForSession:session tag:nil state:YKFNFCConnectionStatePolling errorMessage:nil];
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {

    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        debugPrint("NFC session did detect tags.")
        if tags.count == 0 {
            debugPrint("No tags found");
            self.nfcTagReaderSession?.restartPolling()
            return
        }

        var activeTag: NFCTag? = nil
        for tag in tags {
            if case .iso7816 = tag {
                activeTag = tag
                break
            }
        }

        guard let activeTag = activeTag else {
            debugPrint("No ISO-7816 compatible tags found")
            self.nfcTagReaderSession?.restartPolling()
            return
        }
        self.nfcTagReaderSession?.connect(to: activeTag, completionHandler: { errorObj in
            if let errorObj = errorObj {
                debugPrint("Error: \(errorObj)")
                self.nfcTagReaderSession?.restartPolling()
                return
            }
            debugPrint("NFC session did connect to tag.")
            self.updateServiceForSession(session: self.nfcTagReaderSession,
                                         tag: activeTag,
                                         state: .open)
        })
    }

    func updateServiceForSession(session: NFCTagReaderSession?,
                                 tag: NFCTag?,
                                 state: NFCConnectionState,
                                 errorMessage: String = "") {
        if self.nfcTagReaderSession != session ||
            self.connectionState == state {
            return
        }

       // let previousConnectionState = self.connectionState
        self.connectionState = state
        switch state {
        case .closed:
            self.invalidateNFCSession()
            self.unobserveIso7816TagAvailability()
            self.delegate?.didConnectNFC(manager: self,
                                         connectionState: state,
                                         error: "Connection state")
        case .polling:
            self.unobserveIso7816TagAvailability()
            session?.restartPolling()
            break
        case .open:
            self.tagDescription = NFCTagDescription(tag: tag)
            self.connectionController = NFCConnectionController(tag: tag,
                                                                communicateQueue: self.communicateQueue ?? OperationQueue())
            self.observeIso7816TagAvailability()
            self.delegate?.didConnectNFC(manager: self,
                                         connectionState: state,
                                         error: "")
        }
    }

    func invalidateNFCSession() {
        debugPrint("Command:- invalidateNFCSession")
        self.nfcTagReaderSession?.invalidate()
        self.nfcTagReaderSession = nil
        self.unobserveIso7816TagAvailability()
    }

    //Mark:  Tag availability observation
    func observeIso7816TagAvailability() {

        self.iso7816NfcTagAvailabilityTimer = Timer(fire: Date(), interval: 0.5, repeats: true, block: { timer in
            let isAvailable = self.nfcTagReaderSession?.connectedTag?.isAvailable ?? false
            if isAvailable {
                debugPrint("NFC tag is available.")
            }else {
                debugPrint("NFC tag is available.");
                self.updateServiceForSession(session: self.nfcTagReaderSession,
                                             tag: nil, state: .polling)
            }
        })

        if let timer = self.iso7816NfcTagAvailabilityTimer {
            RunLoop.main.add(timer, forMode: .default)
        }
    }

    func unobserveIso7816TagAvailability() {
        self.iso7816NfcTagAvailabilityTimer?.invalidate()
        self.iso7816NfcTagAvailabilityTimer = nil
    }
}

let pivInsGetSerialNumber: UInt8 = 0xf8
// MARK: Command
extension NFCISO14443ConnectionManager {

    func selectApplication(handler: @escaping (UInt32, Error?) -> Void) {
        debugPrint("Command:- selectApplication")

        let bytes: [UInt8] = [0xA0, 0x00, 0x00, 0x03, 0x08]
        let data1 = NSData(bytes: bytes, length: 5)
        let apdu = APDU(cla: 0x00, ins: 0xA4, p1: 0x04, p2: 0,
                        data: data1.asData, type: .short)
        self.connectionController?.execute(command: apdu, handler: { responseData, timeInterval, error in
            if let error = error {
                debugPrint("Command:- selectApplication Error: \(error.localizedDescription)")
                handler(0, error)
            }else {
                self.getVersion(handler: handler)
            }
        })
    }

    func getVersion(handler: @escaping (UInt32, Error?) -> Void) {
        debugPrint("Command:- getVersion")
        let apdu = APDU(cla: 0x00, ins: 0xfd, p1: 0, p2: 0,
                        data: Data(), type: .short)
        self.connectionController?.execute(command: apdu, handler: { responseData, timeInterval, error in
            if let error = error {
                debugPrint("Command:- getVersion Error: \(error.localizedDescription)")
                handler(0,error)
            }else {
                if let data = responseData,
                    data.count > 2 {
                    let binaryPacket = BinaryPacket(payload: data)
                    let version = NFCVersion(major: binaryPacket.uint8(0),
                                             minor:  binaryPacket.uint8(1),
                                             micro:  binaryPacket.uint8(2))
                    debugPrint("Command:- \(version.major).\(version.micro).\(version.minor)")
                }
                self.getSerialNumber(handler: handler)
            }
        })
    }

    func getSerialNumber(handler: @escaping (UInt32, Error?) -> Void) {
        debugPrint("Command:- getSerialNumber")
        let apdu = APDU(cla: 0, ins: pivInsGetSerialNumber, p1: 0, p2: 0, data: Data(), type: .short)
        self.connectionController?.execute(command: apdu, handler: { responseData, timeInterval, error in
            if let data = responseData, data.count > 4 {
               let binaryPacket = BinaryPacket(payload: data)
                let serialNumber = binaryPacket.uint32(0)
                handler(serialNumber, error)
            }else {
                debugPrint("Command:- getSerialNumber Error: \(String(describing: error?.localizedDescription))")
                handler(0, error)
            }
        })
    }

}

