//
//  SecuredView.swift
//  ScreenProtector
//
//  Created by Ashish Awasthi on 08/08/25.
//
import UIKit


open class CustomSecureView: UIView {

    @IBOutlet public weak var secureView: UIView!
    var storedConstraints: [NSLayoutConstraint] = []
    @IBOutlet public weak var leftConstraint: NSLayoutConstraint!
    @IBOutlet public weak var rightConstraint: NSLayoutConstraint!
    @IBOutlet public weak var topConstraint: NSLayoutConstraint!
    @IBOutlet public weak var bottomConstraint: NSLayoutConstraint!

    required public init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    open override func awakeFromNib() {
        super.awakeFromNib()
        print("SecuredView awakeFromNib called")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.storedConstraints = [self.leftConstraint, self.rightConstraint, self.topConstraint, self.bottomConstraint]
            self.secureView.removeFromSuperview()
            let securedView = SecureViewService.shared.getSecuredView(self.secureView,
                                                                      shouldShowRestrictionMessage: true)
            self.addSubview(securedView)
            securedView.pinEdges()
            NSLayoutConstraint.activate(self.storedConstraints)
        }
    }
}
