//
//  File.swift
//  ThreadIngPOC
//
//  Created by Ashish Awasthi on 19/09/24.
//

import UIKit

 public class PresentationAlertAction: NSObject {
    public static let dismiss = PresentationAlertAction(title: "OK", style: .cancel, handler: nil)
    public typealias PresentationAlertActionHandler = (() -> Void)
    public let title: String
    public let actionHandler: PresentationAlertActionHandler?
    public let style: UIAlertAction.Style

    required public init(title: String, style: UIAlertAction.Style, handler: PresentationAlertActionHandler?) {
        self.title = title
        self.actionHandler = handler
        self.style = style
        super.init()
        self.accessibilityLabel = title
    }

    internal func createUIAlertAction(completionNotifier: PresentationAlertActionHandler?) -> UIAlertAction {
        let action = self.actionHandler
        let alertAction = UIAlertAction(title: self.title, style: self.style) { _ in
            action?()
            completionNotifier?()
        }
        if let label = self.accessibilityLabel {
            alertAction.accessibilityLabel = label
        }
        return alertAction
    }
}

internal class PresentationAlertController: UIAlertController {

    required init?(coder aDecoder: NSCoder) {
        fatalError("Presentation Alert Controller should never be used from Nibs or Storyboards.")
    }

    override init(nibName nibNameOrNil: String?, 
                  bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil,
                   bundle: nibBundleOrNil)
    }

    var dismissHandler: PresentationAlertAction.PresentationAlertActionHandler? = nil

    public convenience init(title: String?, message: String?, dismissHandler: PresentationAlertAction.PresentationAlertActionHandler? = nil) {
        self.init(title: title, message: message, preferredStyle: .alert)
        self.dismissHandler = dismissHandler
    }

    func add(actions: [PresentationAlertAction]) {
        actions.forEach { self.add(action: $0) }
    }

    func add(action: PresentationAlertAction) {
        let completionAction: PresentationAlertAction.PresentationAlertActionHandler = { [weak self] in
            self?.callDismissHandler()
        }
        self.addAction(action.createUIAlertAction(completionNotifier: completionAction))
    }

    override func viewDidDisappear(_ animated: Bool) {
        self.callDismissHandler()
        super.viewDidDisappear(animated)
    }

    func callDismissHandler() {
        self.dismissHandler?()
        self.dismissHandler = nil
    }
}
