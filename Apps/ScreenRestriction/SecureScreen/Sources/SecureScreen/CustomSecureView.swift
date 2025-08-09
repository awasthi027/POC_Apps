//
//  SecuredView.swift
//  ScreenProtector
//
//  Created by Ashish Awasthi on 08/08/25.
//
import UIKit
@MainActor
open class CustomSecureView: UIView {

    @IBOutlet weak var secureView: UIView!
    var storedConstraints: [NSLayoutConstraint] = []
    @IBOutlet weak var leftConstraint: NSLayoutConstraint!
    @IBOutlet weak var rightConstraint: NSLayoutConstraint!
    @IBOutlet weak var topConstraint: NSLayoutConstraint!
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!

    required public init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    open override func awakeFromNib() {
        super.awakeFromNib()
        print("SecuredView awakeFromNib called")
        self.storedConstraints = [leftConstraint,rightConstraint,topConstraint,bottomConstraint]
        self.secureView.removeFromSuperview()
        let securedView = SecureViewService.shared.getSecuredView(self.secureView,
                                                                  shouldShowRestrictionMessage: true)
        self.addSubview(securedView)
        securedView.pinEdges()
        NSLayoutConstraint.activate(storedConstraints)
    }
}

