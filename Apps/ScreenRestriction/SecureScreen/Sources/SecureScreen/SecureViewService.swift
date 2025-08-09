//
//  SecureViewService.swift
//  ScreenProtector
//
//  Created by Ashish Awasthi on 07/08/25.
//

import UIKit

fileprivate struct ScreenCaptureConstants {
    static let canvasViewFromTextField = "LayoutCanvasView"
    static let layerFromView = "layer"
}

internal struct RestrictionLabelConstants {
    static let font: UIFont = .systemFont(ofSize: 17, weight: .semibold)
    static let textColor: UIColor = UIColor.label
    static let textString: String = "Screen capture is restricted in this view for security reasons."
    static let lineBreakMode: NSLineBreakMode = NSLineBreakMode.byTruncatingTail
    static let textAlignment: NSTextAlignment = NSTextAlignment.center
    static let numberOfLines: Int = 2
    static let accessibilityIdentifier: String = "ScreenCaptureRestrictionMessageLabel"
}

@MainActor
public class SecureViewService {

    public static let shared = SecureViewService()
    private init() {}

    public func getSecuredView(_ view: UIView,
                               shouldShowRestrictionMessage: Bool) -> UIView {
        self.getSecureViewWithBanner(view
                                     ,shouldShowRestrictionMessage: shouldShowRestrictionMessage)
    }

    /// This method returns a secure view with a banner message if
    ///         shouldShowRestrictionMessage is true. and
    ///         If not, it returns the secure view without a banner.
    private func getSecureViewWithBanner(_ view: UIView, shouldShowRestrictionMessage: Bool) -> UIView {
        // Securing the layer of the view to prevent screen capture.
        secureLayer(view)
        // If the restriction message should not be shown, return the view as is.
        guard shouldShowRestrictionMessage else {
            return view
        }
        // checking if background of the view is opaque and logging it for debugging purposes.
        if !view.isBackgroundOpaque() {
            print("Background of the view is not opqaue!!! Secure view might not work as expected")
        }
        // Create a container view to hold the restriction message label.
        let container = getContainerViewWithMessage()
        // Now add the secured view to the container.
        container.addSubview(view)
        view.pinEdges()
        return container
    }

    ///This method sets layer of given view to textField, so that the layer becomes secure.
    private func secureLayer(_ view: UIView) {
        let uiKitTextField = UITextField()
        let secureViewFromTextField = uiKitTextField.subviews.first {
            let className = NSStringFromClass(type(of: $0))
            return className.contains(ScreenCaptureConstants.canvasViewFromTextField)
        }

        secureViewFromTextField?.setValue(view.layer, forKey: ScreenCaptureConstants.layerFromView)
        uiKitTextField.isSecureTextEntry = false
        uiKitTextField.isSecureTextEntry = true
    }

    private func getContainerViewWithMessage() -> UIView {
        let containerView = ContainerViewWithMessage()
        containerView.backgroundColor = UIColor.systemBackground
        return containerView
    }
}


internal class ContainerViewWithMessage: UIView {
    var restrictionMessageLabel: UILabel

    override init(frame: CGRect) {
        restrictionMessageLabel = ContainerViewWithMessage.getRestrictionLabel()
        super.init(frame: frame)
        setupView()
    }

    convenience init() {
        self.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        restrictionMessageLabel = ContainerViewWithMessage.getRestrictionLabel()
        super.init(coder: coder)
        setupView()
    }

    func setupView() {
        self.addSubview(restrictionMessageLabel)
        restrictionMessageLabel.pinEdges()
    }

    private static func getRestrictionLabel() -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.text = RestrictionLabelConstants.textString
        label.textColor = RestrictionLabelConstants.textColor
        label.font = RestrictionLabelConstants.font
        label.lineBreakMode = RestrictionLabelConstants.lineBreakMode
        label.numberOfLines = RestrictionLabelConstants.numberOfLines
        label.textAlignment = RestrictionLabelConstants.textAlignment
        label.accessibilityIdentifier = RestrictionLabelConstants.accessibilityIdentifier
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
}
