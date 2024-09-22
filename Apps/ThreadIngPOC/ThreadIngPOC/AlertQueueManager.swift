//
//  AlertQueueManager.swift
//  ThreadIngPOC
//
//  Created by Ashish Awasthi on 19/09/24.
//

import Foundation
import UIKit
public typealias PresentationCompletion = () -> Void

class AlertQueueManager {
    
    private var alertQueue: [PresentationAlertController] = []
    
    @MainActor func addAlertInQueue(alertController: PresentationAlertController, 
                         presenter: UIViewController?) {
        alertQueue.append(alertController)
        if self.alertCounts == 1 {
            self.presentNextAlertFromQueue(presenter: presenter)
        }
    }
    
    @MainActor func presentNextAlertFromQueue(presenter: UIViewController? ) {
        guard let alertController = self.alertQueue.first else {
            print("Alert: No Alert found in Queue")
            return
        }
        let originalDismissHandler = alertController.dismissHandler
        guard let presenter = presenter else {
            print("Alert: Missing Present Controller")
            return
        }
        alertController.dismissHandler = {
            originalDismissHandler?()
            self.alertQueue.removeFirst()
            self.presentNextAlertFromQueue(presenter: presenter)
        }
        presenter.present(alertController, animated: true)
        return
    }
    
    var alertCounts: Int {
        self.alertQueue.count
    }
}
