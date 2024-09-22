//
//  TestViewController.swift
//  ThreadIngPOC
//
//  Created by Ashish Awasthi on 21/09/24.
//

import Foundation
import UIKit

enum ViewControllerType {
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
    var color: UIColor {
        switch self {
        case .serverDetails: return .red
        case .userAuthentication: return .yellow
        case .createPasscode:  return .purple
        }
    }
}

class TestViewController: UIViewController {

    var viewControllerType: ViewControllerType = .serverDetails
     override func viewDidLoad() {
        super.viewDidLoad()
         self.title = viewControllerType.title
         self.view.backgroundColor = viewControllerType.color
         self.customButtonTitle(title: viewControllerType.title)
    }

    func customButtonTitle(title: String) {
        let uiButton = UIButton(frame: CGRect(x: 10, y: 200, width: 200, height: 40))
        uiButton.setTitle(title, for: .normal)
        uiButton.backgroundColor = .green
        uiButton.addTarget(self, action: #selector(self.showNextView), for: .touchUpInside)
        self.view.addSubview(uiButton)
    }

    @objc func showNextView() {
        switch self.viewControllerType {
        case .serverDetails:
            let operationSecond = PresentUIControllerOperation(sdkManager: SDKManager.shared,
                                                        dataContext: SDKManager.shared.dataContext,
                                                        presenter: SDKManager.shared.presenter)
            operationSecond.viewControllerType = .userAuthentication
            SDKOperationQueues.uiOperationQueue.addOperation(operationSecond)
            operationSecond.waitUntilFinished()
        case .userAuthentication:
            let operationThird = PresentUIControllerOperation(sdkManager: SDKManager.shared,
                                                        dataContext: SDKManager.shared.dataContext,
                                                        presenter: SDKManager.shared.presenter)
            operationThird.viewControllerType = .createPasscode
            SDKOperationQueues.uiOperationQueue.addOperation(operationThird)
            operationThird.waitUntilFinished()
        case .createPasscode:
            SDKManager.shared.showSequenceAlert()
        }
    }
}
