//
//  XibViewController.swift
//  ScreenProtector
//
//  Created by Ashish Awasthi on 09/08/25.
//



import UIKit
import WebKit

class XibViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        let secureView = SecureSubViews.loadFromNib()
        var viewFrame: CGRect = self.view.bounds
        secureView.frame = viewFrame
        self.view.addSubview(secureView)

    }
    override func viewWillAppear(_ animated: Bool) {
         super.viewWillAppear(animated)
    }
}
