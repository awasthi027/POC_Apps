//
//  NFCConnectionController.swift
//  NFCPOC
//
//  Created by Ashish Awasthi on 20/10/23.
//

import Foundation
import CoreNFC


public typealias CommandHandler = (Data?, TimeInterval?, Error?) -> Void
let NFCConnectionDefaultTimeout = 10.0

class NFCConnectionController {
    var tag: NFCTag?
    var communicateQueue: OperationQueue


    init(tag: NFCTag? = nil,
         communicateQueue: OperationQueue) {
        self.tag = tag
        self.communicateQueue = communicateQueue
    }

    func execute(command: APDU, handler: @escaping CommandHandler) {
        self.execute(command: command,
                     timeOut: NFCConnectionDefaultTimeout,
                     handler: handler)
    }

   private func execute(command: APDU,
                 timeOut: TimeInterval,
                 handler: @escaping CommandHandler) {
        debugPrint("NFCCommand:- - Start command...")
        self.dispatchBlockOnCommunicationQueue { operation in
            if operation.isCancelled {
                return
            }
            guard let tag = self.tag,
                    tag.isAvailable else {
                debugPrint("NFCCommand:- Tag is not available.")
                handler(nil, nil, self.errorObject(errorCode: .connectionLost))
                return
            }

            var executionResult: Data?
            var executionError: Error?
            let execuationDate: Date = Date()

            if case .iso7816(let nfcISO7816Tag) = tag,
               let nfcISO7816APDU = NFCISO7816APDU(data: command.apduData) {
                debugPrint("NFCCommand:- Hex Value: \(command.apduData.hexDescription)")
                debugPrint("NFCCommand:- Send command...")
                let semaphore = DispatchSemaphore(value: 0)

                nfcISO7816Tag.sendCommand(apdu: nfcISO7816APDU) { result in
                    debugPrint("NFCCommand:- result")
                    switch result {
                    case .success(let item):
                        debugPrint("NFCCommand:- Success: word1: \(item.statusWord1),  word2: \(item.statusWord2)")
                        var fullResponse = Data(item.payload ?? Data())
                        fullResponse.appendUInt8(item.statusWord1)
                        fullResponse.appendUInt8(item.statusWord2)
                        executionResult = fullResponse
                        semaphore.signal()
                        break

                    case .failure(let error):
                        debugPrint("NFCCommand:- failed")
                        executionError = error
                        semaphore.signal()
                        return

                    }
                }
                let _ = semaphore.wait(timeout: DispatchTime.now() + timeOut)
            }

            if operation.isCancelled {
                return
            }

            let timeInterval = Date().timeIntervalSince(execuationDate)
            if let error = executionError {
                handler(nil, timeInterval, error)
            }else {
                handler(executionResult, timeInterval, nil)
            }
        }
    }

    func dispatchBlockOnCommunicationQueue(queueHandler: @escaping(Operation) ->Void) {
        let operation = BlockOperation()
        operation.addExecutionBlock {
            guard operation.isCancelled else {
                return queueHandler(operation)
            }
        }
        self.communicateQueue.addOperation(operation)
    }

    func errorObject(errorCode: SessionErrorCode) -> NSError {
        return NSError(domain: "NFCSession", code: errorCode.rawValue)
    }

    func cancelAllCommands() {
        self.communicateQueue.isSuspended = true
        self.communicateQueue.cancelAllOperations()
        self.communicateQueue.isSuspended = false
    }
}


