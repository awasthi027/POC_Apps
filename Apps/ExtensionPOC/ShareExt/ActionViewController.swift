//
//  ShareViewController.swift
//  ShareExt
//
//  Created by Ashish Awasthi on 29/06/25.
//
import UIKit
import MobileCoreServices
import LearningSubspecSDK
import os.log


class ActionViewController: UIViewController {

    @IBOutlet var intructionLabel: UILabel!
    let logger = OSLog(subsystem: "ashi.com.com.ExtensionPOC.ShareExt",
                       category: "ExtensionPOCApp.ShareExt")

    let learningSDKManager: LearningSDKManager = LearningSDKManager()
    var messageStr: String = ""
    override func viewDidLoad() {
        super.viewDidLoad()
        os_log("Extension started processing", log: logger, type: .default)
       // os_log("Extension started processing", log: logger, type: .info)

        learningSDKManager.delegate = self
        intructionLabel.accessibilityIdentifier = "IntructionLabel"
        messageStr.append("viewDidLoad")
        self.intructionLabel.text = messageStr
        let sdkName = LearningSDKManager.extensionSafeAccessMethod()
        let basicFeatureAccess = LearningSDKManager.basicInfoMethod()
        let sdkVersion = LearningSDKManager.getSDKVersion()
        messageStr.append("\nSDK Name: \(sdkName)")
        messageStr.append("\nSDK Version:\(sdkVersion)")
        os_log("SDK Name: %@", log: logger, type: .info, sdkName)
        os_log("SDK Version: %@", log: logger, type: .debug, sdkVersion)
        os_log("BasicInfo: %@", log: logger, type: .fault, basicFeatureAccess)
        self.intructionLabel.text = messageStr

        NSLog("App launched - NSLog statement")
        NSLog("Device: %@, iOS %@",
                 UIDevice.current.name,
                 UIDevice.current.systemVersion)

    }


    @IBAction func didClickOnLaunchView(sender: AnyObject) {
        self.learningSDKManager.authenticateUser()
//        let viewController = UIViewController()
//        viewController.view.backgroundColor = .systemBlue
//        viewController.navigationItem.title = "Launch View"
//        self.present(viewController, animated: true)
    }

    @IBAction func didClickNavigationDoneButton(sender: AnyObject) {
        // Return any edited content to the host app.
        // This template doesn't do anything, so we just echo the passed in items.
        self.extensionContext!.completeRequest(returningItems: self.extensionContext!.inputItems, completionHandler: nil)
    }

}

extension ActionViewController: SDKStateProtocol {

    func sdkInitComplete() {
        messageStr.append("sdkInitComplete")
        os_log("sdkInitComplete", log: logger, type: .info)
        intructionLabel.text = messageStr
    }
}

extension ActionViewController: ExtensionRefProtocol {

    func getExtensionToViewController() -> UIViewController {
        messageStr.append("\nPresenter Delegate Called")
        os_log("Presenter Delegate Called", log: logger, type: .info)
        intructionLabel.text = messageStr
        return self
    }
}

