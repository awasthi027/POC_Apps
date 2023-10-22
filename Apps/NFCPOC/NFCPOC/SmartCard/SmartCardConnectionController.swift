//
//  SmartCardConnectionController.swift
//  NFCPOC
//
//  Created by Ashish Awasthi on 22/10/23.
//

import Foundation
import CryptoTokenKit

class SmartCardConnectionController: NSObject {
    
    var communicateQueue: OperationQueue = OperationQueue()
    private var smartCard: TKSmartCard?

    override init() {
        super.init()
        communicateQueue.maxConcurrentOperationCount = 1
        let concurrentQueue = DispatchQueue(label: "connectionSmartCard", attributes: .concurrent)
        self.communicateQueue.underlyingQueue = concurrentQueue
    }

    class func smartCardControllerWithSmartCard(smartCard: TKSmartCard,
                                                handler: @escaping(SmartCardConnectionController, Error?) -> Void) {
        debugPrint("SmartCardCommand:- execute")
        let connectionController = SmartCardConnectionController()
        connectionController.smartCard = smartCard
        smartCard.beginSession { isSucces, error in
            debugPrint("SmartCardCommand:- Begain session")
            if let error = error {
                debugPrint("SmartCardCommand:- Error in session")
                handler(connectionController, error)
            }else {
                handler(connectionController, nil)
            }
        }
    }
    
    func endSession() {
        self.smartCard?.endSession()
        self.smartCard = nil
    }
    
    func cancelAllCommands() {
        self.communicateQueue.isSuspended = true
        self.communicateQueue.cancelAllOperations()
        self.communicateQueue.isSuspended = false
    }
}

//MARK: Execute commands
extension SmartCardConnectionController {

    func execute(command: APDU, handler: @escaping CommandHandler) {
        self.execute(command: command,
                     timeOut: NFCConnectionDefaultTimeout,
                     handler: handler)
    }

    func execute(command: APDU,
                 timeOut: TimeInterval,
                 handler: @escaping CommandHandler) {
        debugPrint("SmartCardCommand:- execute")
        self.dispatchBlockOnCommunicationQueue { operation in
            if operation.isCancelled {
                return
            }

            if let smartCard = self.smartCard,
                !smartCard.isValid {
                handler(nil, nil, self.errorObject(errorCode: .connectionLost))
                return
            }
            debugPrint("SmartCardCommand:- Start")
            guard let smartCard = self.smartCard else {
                return
            }
            var executionResult: Data?
            var executionError: Error?
            let execuationDate: Date = Date()
            let semaphore = DispatchSemaphore(value: 0)
            debugPrint("SmartCardCommand:- Enter")
            smartCard.transmit(command.apduData) { responseData, error in
                if let error = error {
                    debugPrint("SmartCardCommand:- Fail")
                    executionError = error
                    semaphore.signal()

                }else {
                    debugPrint("SmartCardCommand:- Success")
                    executionResult = responseData
                    semaphore.signal()

                }
            }
            let _ = semaphore.wait(timeout: DispatchTime.now() + timeOut)
            if operation.isCancelled {
                return
            }
            let timeInterval = Date().timeIntervalSince(execuationDate)
            debugPrint("SmartCardCommand:- Result")
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
        return NSError(domain: "SmartCardSession", code: errorCode.rawValue)
    }
}

