//
//  Untitled.swift
//  ThreadIngPOC
//
//  Created by Ashish Awasthi on 20/09/24.
//

import Foundation

internal class DismissSDKUIControllOperation: SDKOperation,
                                      @unchecked Sendable {

    required init(sdkManager: SDKManager,
                  dataContext: SDKContext,
                  presenter: SDKQueuePresenter) {
        super.init(sdkManager: sdkManager,
                   dataContext: dataContext,
                   presenter: presenter)
    }

    override func startOperation() {
          self.dismissSDKUIControll()
    }

    func dismissSDKUIControll() {
        self.presenter.dismissSDKUIControll()
        self.markOperationComplete()
    }
}
