//
//  DisplayAlertOperation .swift
//  ThreadIngPOC
//
//  Created by Ashish Awasthi on 19/09/24.
//

import Foundation

enum AlertType {
    case serverDetails
    case userAuthentication
    case createPasscode

    var message: String {
        switch self {
        case .serverDetails: return "Enter host url and OG"
        case .userAuthentication: return "Authenticate User by enter username and password"
        case .createPasscode:  return "Enter your passcode"
        }
    }

    var title: String {
        switch self {
        case .serverDetails: return "Enter host url and OG"
        case .userAuthentication: return "User Authentication"
        case .createPasscode:  return "Create Passcode"
        }
    }
}

internal class DisplayAlertOperation: SDKOperation,
                                      @unchecked Sendable {
    var alertType: AlertType = .serverDetails

    required init(sdkManager: SDKManager,
                  dataContext: SDKContext, 
                  presenter: SDKQueuePresenter) {
        super.init(sdkManager: sdkManager,
                   dataContext: dataContext,
                   presenter: presenter)
    }
    
    override func startOperation() {
          self.showWarningAlertToUser()
    }

    // Display SSL warning alert
    func showWarningAlertToUser() {
        let blockAction = PresentationAlertAction(title: "Block", style: .default) {
            print("UserConsent: User rejected default PIN handling")
        }

        let continueAction = PresentationAlertAction(title: "Continue", style: .cancel) {
            print( "UserConsent: User accepted default PIN handling")
        }
        self.presenter.showAlert(title: self.alertType.title,
                                 message: self.alertType.message,
                                 actions: [blockAction, continueAction]) {
            self.markOperationComplete()
            if self.alertType == .createPasscode {
                self.presenter.callBackDelegate?.didSDKInitializationComplete()
            }
        }
    }
}
