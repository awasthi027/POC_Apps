//
//  SecureEntireViewController.swift
//  ScreenProtector
//
//  Created by Ashish Awasthi on 07/08/25.
//


import UIKit
import SecureScreen

class SecureEntireViewController: UIViewController {
    class func secureEntireViewController() -> SecureEntireViewController?  {
        return UIStoryboard.main.instantiateViewController(withIdentifier:
                                                                        String(describing: SecureEntireViewController.self)) as? SecureEntireViewController

    }
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view = SecureViewService.shared.getSecuredView(self.view,
                                                            shouldShowRestrictionMessage: true)
    }
}
