//
//  SDKManager.swift
//  ThreadIngPOC
//
//  Created by Ashish Awasthi on 17/09/24.
//

import Foundation


class SDKManager: NSObject {

    static let shared: SDKManager = SDKManager()
    internal var presenter: SDKQueuePresenter = SDKQueuePresenter(presentation: ApplicationSDKPresentation())
    internal var dataContext: SDKContext = SDKContext()

    override init() {
        /* No Action */
    }

    func startSDK() {
        self.presenter.callBackDelegate = self
        self.presentServerDetails()
    }
    
    func presentServerDetails() {
        let operationFirst = PresentUIControllerOperation(sdkManager: self,
                                                   dataContext: self.dataContext,
                                                   presenter: self.presenter)
        operationFirst.viewControllerType = .serverDetails
        SDKOperationQueues.uiOperationQueue.addOperation(operationFirst)
        operationFirst.waitUntilFinished()
    }

    func sdkStartComplete() {
        let operationSecond = DismissSDKUIControllOperation(sdkManager: self,
                                                            dataContext: self.dataContext,
                                                            presenter: self.presenter)
        SDKOperationQueues.uiOperationQueue.addOperation(operationSecond)
        operationSecond.waitUntilFinished()
    }

    func showSequenceAlert() {
        let operationFirst = DisplayAlertOperation(sdkManager: self,
                                                   dataContext: self.dataContext,
                                                   presenter: self.presenter)
        operationFirst.alertType = .serverDetails
        SDKOperationQueues.uiOperationQueue.addOperation(operationFirst)
        operationFirst.waitUntilFinished()

        let operationSecond = DisplayAlertOperation(sdkManager: self,
                                                    dataContext: self.dataContext,
                                                    presenter: self.presenter)
        operationSecond.alertType = .userAuthentication
        SDKOperationQueues.uiOperationQueue.addOperation(operationSecond)
        operationSecond.waitUntilFinished()

        let operationThird = DisplayAlertOperation(sdkManager: self,
                                                    dataContext: self.dataContext,
                                                    presenter: self.presenter)
        operationThird.alertType = .createPasscode
        SDKOperationQueues.uiOperationQueue.addOperation(operationThird)
        operationThird.waitUntilFinished()
    }
}

extension SDKManager: SDKExecutionStateProtocol {
    func didSDKInitializationComplete() {
        print("SDKState: didSDKInitializationComplete")
        self.sdkStartComplete()
    }
}

struct Bar {}
protocol P {
    func printMessage()
}

#if hasFeature(RetroactiveAttribute)
extension Bar: P {
    public func printMessage() {
        print("New Messge RetroactiveAttribute")
    }
}
#else
extension Bar: P {
    public func printMessage() {
        print("New Messge")
    }
}
#endif
