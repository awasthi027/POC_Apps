//
//  CrossAppEventManager.swift
//  AACoreHelperSampleApp
//
//  Created by Ashish Awasthi on 05/06/25.
//

import Foundation
import CoreHelpers

class CrossAppEventManager {

    init() {
        self.monitorCrossAppEvents()

    }
    // This method is responsible for adding observer to AWController
    internal func monitorCrossAppEvents() {
        CrossAppEventHandler.shared.on("SessionUpdate", execute: self.handleSDKEvent)
        CrossAppEventHandler.shared.on("Unenroll", execute: self.handleSDKEvent)
        CrossAppEventHandler.shared.on("checkin", execute: self.handleSDKEvent)
    }

    // Received cross app event from other SDK apps to
    // handle cross app event and refresh SDK
    // - Parameter event: received cross app event from other SDK supported apps
    internal func handleSDKEvent(_ event: CrossAppEvent) {
       print("Received cross app event for \(event)")
    }

}
