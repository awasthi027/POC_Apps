//
//  CloudQuery.swift
//  CloudService
//
//  Created by Tanuja Awasthi on 01/02/21.
//  Copyright © 2021 Tanuja Awasthi. All rights reserved.
//

import Foundation

public enum AppWorkingState {
    case background
    case suspend
    case becomeActive
    case resignActive
    case forground
    case unknown
}

public enum CloudSyncQueryRequest {
    case appState
    case undefined
}

public enum CloudSyncQueryResp {
    case appState(AppWorkingState)
    case undefined
}
