//
//  PresentUIControllerOperation.swift
//  ThreadIngPOC
//
//  Created by Ashish Awasthi on 21/09/24.
//

import Foundation

internal class PresentUIControllerOperation: SDKOperation,
                                      @unchecked Sendable {
    var viewControllerType: ViewControllerType = .serverDetails
    required init(sdkManager: SDKManager,
                  dataContext: SDKContext,
                  presenter: SDKQueuePresenter) {
        super.init(sdkManager: sdkManager,
                   dataContext: dataContext,
                   presenter: presenter)
    }

    override func startOperation() {
          self.showViewController()
    }

    func showViewController() {
        DispatchQueue.main.async {
            let testViewController = TestViewController()
            testViewController.viewControllerType = self.viewControllerType
            self.presenter.presentViewController(viewController: testViewController) { isSuccess in
                self.markOperationComplete()
            }
        }
    }
}
