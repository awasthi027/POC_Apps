//
//  ShareViewController.swift
//  ShareExtUITest
//
//  Created by Ashish Awasthi on 27/06/25.
//

import UIKit
import Social

class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func didClickToLaunchView() {
        let viewController = UIViewController()
        viewController.view.backgroundColor = .systemBlue
        viewController.navigationItem.title = "Launch View"
        self.present(viewController, animated: true)
    }

}
