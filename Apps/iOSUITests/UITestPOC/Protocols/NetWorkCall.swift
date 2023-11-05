//
//  NetWorkCall.swift
//  UITestPOC
//
//  Created by Ashish Awasthi on 05/11/23.
//

import Foundation
import CloudService

protocol NetworkLibProtocol {
    var cloudService: CloudService { get  set}
}

open class NetWorkCall: NetworkLibProtocol {
    private var _cloudService: CloudService = CloudService.default

    var cloudService: CloudService {
        get { return _cloudService}
        set {
            _cloudService = newValue
        }
    }
}
