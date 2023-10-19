//
//  NFCTagDetailsViewModel.swift
//  NFCPOC
//
//  Created by Ashish Awasthi on 19/10/23.
//

import Foundation
import CoreNFC

class NFCTagDetailsViewModel: ObservableObject {

    var message: NFCNDEFMessage = .init(records: [])
  
   @Published var reconds: [NFCNDEFPayload] = []

    func publishRecords() {
        self.reconds = self.message.records
    }
}

extension NFCNDEFPayload {

    var displayMessage: String {
        var message: String = ""
        switch self.typeNameFormat {
        case .nfcWellKnown:
            if let type = String(data: self.type, encoding: .utf8) {
                if let url = self.wellKnownTypeURIPayload() {
                    message = "\(self.typeNameFormat.description): \(type), \(url.absoluteString)"
                } else {
                    message = "\(self.typeNameFormat.description): \(type)"
                }
            }
        case .absoluteURI:
            if let text = String(data: self.payload, encoding: .utf8) {
                message = text
            }
        case .media:
            if let type = String(data: self.type, encoding: .utf8) {
                message = "\(self.typeNameFormat.description): " + type
            }
        case .nfcExternal, .empty, .unknown, .unchanged:
            fallthrough
        @unknown default:
            message = self.typeNameFormat.description
        }
        return message
    }
}

extension NFCTypeNameFormat: CustomStringConvertible {
    public var description: String {
        switch self {
        case .nfcWellKnown: return "NFC Well Known type"
        case .media: return "Media type"
        case .absoluteURI: return "Absolute URI type"
        case .nfcExternal: return "NFC External type"
        case .unknown: return "Unknown type"
        case .unchanged: return "Unchanged type"
        case .empty: return "Empty payload"
        @unknown default: return "Invalid data"
        }
    }
}

class WriteConnectionManager: NSObject, ObservableObject {
    var message: NFCNDEFMessage = .init(records: [])

    var session: NFCNDEFReaderSession?
    /// Messages
    @Published var detectedMessages: [NFCNDEFMessage] = []

    func startNFCSession() {
        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        session?.alertMessage = "Hold your iPhone near an NDEF tag to write the message."
        session?.begin()
    }

    var isSupportingNFCScaning: Bool {
        return NFCNDEFReaderSession.readingAvailable
    }
}



extension WriteConnectionManager: NFCNDEFReaderSessionDelegate {

    // MARK: - NFCNDEFReaderSessionDelegate

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
    }

    /// - Tag: writeToTag
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        if tags.count > 1 {
            // Restart polling in 500 milliseconds.
            let retryInterval = DispatchTimeInterval.milliseconds(500)
            session.alertMessage = "More than 1 tag is detected. Please remove all tags and try again."
            DispatchQueue.global().asyncAfter(deadline: .now() + retryInterval, execute: {
                session.restartPolling()
            })
            return
        }

        // Connect to the found tag and write an NDEF message to it.
        let tag = tags.first!
        session.connect(to: tag, completionHandler: { (error: Error?) in
            if nil != error {
                session.alertMessage = "Unable to connect to tag."
                session.invalidate()
                return
            }

            tag.queryNDEFStatus(completionHandler: { (ndefStatus: NFCNDEFStatus, capacity: Int, error: Error?) in
                guard error == nil else {
                    session.alertMessage = "Unable to query the NDEF status of tag."
                    session.invalidate()
                    return
                }

                switch ndefStatus {
                case .notSupported:
                    session.alertMessage = "Tag is not NDEF compliant."
                    session.invalidate()
                case .readOnly:
                    session.alertMessage = "Tag is read only."
                    session.invalidate()
                case .readWrite:
                    tag.writeNDEF(self.message, completionHandler: { (error: Error?) in
                        if nil != error {
                            session.alertMessage = "Write NDEF message fail: \(error!)"
                        } else {
                            session.alertMessage = "Write NDEF message successful."
                        }
                        session.invalidate()
                    })
                @unknown default:
                    session.alertMessage = "Unknown NDEF tag status."
                    session.invalidate()
                }
            })
        })
    }

    /// - Tag: sessionBecomeActive
    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {

    }

    /// - Tag: endScanning
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        // Check the invalidation reason from the returned error.
        if let readerError = error as? NFCReaderError {
            // Show an alert when the invalidation reason is not because of a success read
            // during a single tag read mode, or user canceled a multi-tag read mode session
            // from the UI or programmatically using the invalidate method call.
            if (readerError.code != .readerSessionInvalidationErrorFirstNDEFTagRead)
                && (readerError.code != .readerSessionInvalidationErrorUserCanceled) {
//                let alertController = UIAlertController(
//                    title: "Session Invalidated",
//                    message: error.localizedDescription,
//                    preferredStyle: .alert
//                )
//                alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
//                DispatchQueue.main.async {
//                    self.present(alertController, animated: true, completion: nil)
//                }
            }
        }
    }
}
