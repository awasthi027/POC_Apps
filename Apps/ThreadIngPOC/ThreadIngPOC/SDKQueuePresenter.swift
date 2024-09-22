//
//  SDKQueuePresenter.swift
//  ThreadIngPOC
//
//  Created by Ashish Awasthi on 19/09/24.
//

import Foundation
import UIKit

internal class ApplicationSDKPresentation: NSObject {
    var presentationHandler: UIWindow? = nil

    /// SDKPresentationDelegate func implementation
    /// - Returns: Returns cached presentation handler, else creates a new handler and caches the same
    func getPresentationHandler() -> UIWindow? {
        if let handler = self.presentationHandler {
            return handler
        }

        let presentationWindow: UIWindow
        let scene = UIApplication
            .shared
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
        if let windowScene = scene {
            presentationWindow = UIWindow(windowScene: windowScene)
        } else {
            presentationWindow = UIWindow(frame: UIScreen.main.bounds)
        }

        let rootView = UIViewController(nibName: nil, bundle: nil)
        let uiNavigationController = UINavigationController(rootViewController: rootView)
        rootView.view.backgroundColor = .blue
        presentationWindow.rootViewController = uiNavigationController
        presentationWindow.makeKeyAndVisible()
        self.presentationHandler = presentationWindow
        return presentationWindow
    }

    var presentViewController: UIViewController? {
        guard let item = self.getPresentationHandler()?.rootViewController?.presentedViewController else {
            return self.getPresentationHandler()?.rootViewController
        }
        return item
    }
}

public typealias PresenterCompletion = (() -> Void)?
public typealias AlertDismissCompletion = (() -> Void)?

internal protocol PresentUIActionProtocol  {
    func showAlert(title: String,
                   message: String,
                   actions: [PresentationAlertAction],
                   onDismiss: AlertDismissCompletion)
    func presentViewController(viewController: UIViewController,
                               complete: @escaping(Bool) -> Void)
    func dismissSDKUIControll()
}


internal protocol SDKExecutionStateProtocol: NSObjectProtocol {
    func didSDKInitializationComplete()
}

class SDKQueuePresenter: PresentUIActionProtocol {

    var presentation: ApplicationSDKPresentation?
    var alertQueueManager: AlertQueueManager = AlertQueueManager()
    weak var callBackDelegate: SDKExecutionStateProtocol?

    init(presentation: ApplicationSDKPresentation? = nil) {
        self.presentation = presentation
    }
    /// Displays the given information in an alert manner so that
    ///
    /// - Parameters:
    ///   - title: String to display as Alert's Title.
    ///   - message: String to display as Alert's Message.
    ///   - actions: An Array of PresentationAlertAction that will be used as actions on the alert.
    ///   - onDismiss: Completion to be called when the alert is dismissed
    func showAlert(title: String,
                   message: String,
                   actions: [PresentationAlertAction] = [],
                   onDismiss: AlertDismissCompletion = nil) {
        DispatchQueue.main.async {
            let controller = PresentationAlertController(title: title,
                                                         message: message,
                                                         dismissHandler: onDismiss)
            if actions.count == 0 {
                controller.add(actions: [PresentationAlertAction.dismiss])
            } else {
                controller.add(actions: actions)
            }
            self.alertQueueManager.addAlertInQueue(alertController: controller,
                                                   presenter: self.presentation?.presentViewController)
        }
    }

    func presentViewController(viewController: UIViewController,
                               complete: @escaping(Bool) -> Void) {
        guard let currentPresentController = self.presentation?.presentViewController else {
            complete(false)
            return
        }
        currentPresentController.show(viewController, sender: nil)
        complete(true)
    }
    
    func dismissSDKUIControll() {
        self.presentation?.presentationHandler = nil
    }
}
