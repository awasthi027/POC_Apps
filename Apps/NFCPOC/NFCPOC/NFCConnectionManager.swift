//
//  NFCConnectionManager.swift
//  NFCPOC
//
//  Created by Ashish Awasthi on 16/10/23.
//

import Foundation
import CoreNFC

class NFCConnectionManager: NSObject, ObservableObject {

    var session: NFCNDEFReaderSession?
    /// Messages
    @Published var detectedMessages: [NFCNDEFMessage] = []

    func startNFCSession() {
        session = NFCNDEFReaderSession(delegate: self, queue: DispatchQueue.main, invalidateAfterFirstRead: false)
        session?.alertMessage = "Hold your iPhone near the item to learn more about it."
        session?.begin()
    }

    var isSupportingNFCScaning: Bool {
        return NFCNDEFReaderSession.readingAvailable
    }
}

extension NFCNDEFMessage {

    var displayMessage: String {
        let unit = self.records.count == 1 ? " Payload" : " Payloads"
        return records.count.description + unit
    }
}

extension NFCConnectionManager: NFCNDEFReaderSessionDelegate {

    /// - Tag: sessionBecomeActive
    /// This method will called when NFC session become active
    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
          debugPrint("NFC session become active======")
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // Process detected NFCNDEFMessage objects.
        self.detectedMessages.append(contentsOf: messages)

        for message in messages {
            for record in message.records {
                print("Type name format: \(record.typeNameFormat)")
                print("Payload: \(record.payload)")
                print("Type: \(record.type)")
                print("Identifier: \(record.identifier)")
            }
        }
    }

    /// - Tag: processingNDEFTag
    /// if This method is not implement then only   func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) will call
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        if tags.count > 1 {
            // Restart polling in 500ms
            let retryInterval = DispatchTimeInterval.milliseconds(500)
            session.alertMessage = "More than 1 tag is detected, please remove all tags and try again."
            DispatchQueue.global().asyncAfter(deadline: .now() + retryInterval, execute: {
                session.restartPolling()
            })
            return
        }

        // Connect to the found tag and perform NDEF message reading
        let tag = tags.first!
        session.connect(to: tag, completionHandler: { (error: Error?) in
            if nil != error {
                session.alertMessage = "Unable to connect to tag."
                session.invalidate()
                return
            }

            tag.queryNDEFStatus(completionHandler: { (ndefStatus: NFCNDEFStatus, capacity: Int, error: Error?) in
                if .notSupported == ndefStatus {
                    session.alertMessage = "Tag is not NDEF compliant"
                    session.invalidate()
                    return
                } else if nil != error {
                    session.alertMessage = "Unable to query NDEF status of tag"
                    session.invalidate()
                    return
                }

                tag.readNDEF(completionHandler: { (message: NFCNDEFMessage?, error: Error?) in
                    var statusMessage: String
                    if nil != error || nil == message {
                        statusMessage = "Fail to read NDEF from tag"
                    } else {
                        statusMessage = "Found 1 NDEF message"
                        DispatchQueue.main.async {
                            // Process detected NFCNDEFMessage objects.
                            self.detectedMessages.append(message!)
                            //self.tableView.reloadData()
                        }
                    }

                    session.alertMessage = statusMessage
                    session.invalidate()
                })
            })
        })
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        print("Error: \(error.localizedDescription)")
    }

}
