//
//  File.swift
//  ThreadIngPOC
//
//  Created by Ashish Awasthi on 19/09/24.
//

import Foundation

internal class SDKOperationQueues: OperationQueue,
                                    @unchecked Sendable {

    struct Constants {
        //Execute UI Operation in this queue, can execute only one operation at time
        static let uiOperationQueue            = "com.ashi.com.uiOperationQueue"
        // Execute Data Operation in this queue, Can execute multitple parallel operations
        static let dataSourceQueue             = "com.ashi.com.dataSourceQueue"
        // Handle cloud challenge in this queue example: SSL Pinning, Authentication, data validation
        // This serial queue, can execute only one operation at time
        static let cloudChallenageQueue        = "com.ashi.com.cloudChallenageQueue"
        // this is generic queue, Can execute multitple parallel operations
        static let genericQueue                = "com.ashi.com.genericQueue"
    }

    static private(set) var uiOperationQueue             = SDKOperationQueues(name: Constants.uiOperationQueue,
                                                                              qualityOfService: .userInteractive,
                                                                              maxConcurrentOperationCount: 1)
    static private(set) var dataSourceQueue              = SDKOperationQueues(name: Constants.dataSourceQueue,
                                                                              qualityOfService: .userInitiated)
    static private(set) var cloudChallenageQueue         = SDKOperationQueues(name: Constants.cloudChallenageQueue,
                                                                              qualityOfService: .background,
                                                                              maxConcurrentOperationCount: 1)
    static private(set) var genericQueue                 = SDKOperationQueues(name: Constants.genericQueue,
                                                                              qualityOfService: .utility)
    
    private init(name: String,
                 qualityOfService: QualityOfService,
                 maxConcurrentOperationCount: Int = 0) {
        super.init()
        self.name = name
        if maxConcurrentOperationCount > 0 {
            self.maxConcurrentOperationCount = maxConcurrentOperationCount
        }
    }

    static func reset() {
        uiOperationQueue.cancelAllOperations()
        SDKOperationQueues.uiOperationQueue = SDKOperationQueues(name: Constants.uiOperationQueue,
                                                                 qualityOfService: .userInteractive,
                                                                 maxConcurrentOperationCount: 1)
        dataSourceQueue.cancelAllOperations()
        SDKOperationQueues.dataSourceQueue = SDKOperationQueues(name: Constants.dataSourceQueue,
                                                                qualityOfService: .userInitiated)

        cloudChallenageQueue.cancelAllOperations()
        SDKOperationQueues.cloudChallenageQueue = SDKOperationQueues(name: Constants.cloudChallenageQueue,
                                                                     qualityOfService: .background,
                                                                     maxConcurrentOperationCount: 1)
        // Reseting SSL Pinning Warning Queue
        genericQueue.cancelAllOperations()
        SDKOperationQueues.genericQueue = SDKOperationQueues(name: Constants.genericQueue,
                                                             qualityOfService: .utility)
    }
}
