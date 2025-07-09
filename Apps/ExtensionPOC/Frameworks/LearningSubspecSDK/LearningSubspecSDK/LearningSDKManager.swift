//
//  LearningSDKManager.swift
//  LearningSubspecSDK
//
//  Created by Ashish Awasthi on 04/07/25.
//
import Foundation
import UIKit

#if Extension_Safe_API
public protocol ExtensionRefProtocol {
    func getExtensionToViewController() -> UIViewController
}
#endif

public protocol SDKStateProtocol {
    func sdkInitComplete()
}

public class LearningSDKManager {

    var viewController: UIViewController?  = UIViewController()

    public init() { }

    public var delegate: ExtensionRefProtocol?

    public class func getSDKVersion() -> String {
        return "1.0.0"
    }
#if Extension_Safe_API
    public class func extensionSafeAccessMethod() -> String {
        return "Learning Subspec SDK"
    }
#endif

#if Basic_Info
    public class func basicInfoMethod() -> String {
        return "Just Testing Method under basic info default availabe"
    }
#endif

    public func authenticateUser() {

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.viewController?.view.backgroundColor = .systemBlue
            let button = UIButton(type: .custom)
            button.setTitle("Dismiss", for: .normal)
            button.addTarget(self, action: #selector(self.dismissController), for: .touchUpInside)
            button.sizeToFit()
            button.center = self.viewController?.view.center ?? CGPoint.zero
            self.viewController?.view.addSubview(button)
            let rootViewController = self.delegate?.getExtensionToViewController()
             rootViewController?.present(self.viewController!, animated: true)
        }
    }

    @objc func dismissController() {
        self.viewController?.dismiss(animated: true)
        self.viewController = nil
    }
}
