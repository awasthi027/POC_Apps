//
//  ViewController.swift
//  ScreenProtector
//
//  Created by Ashish Awasthi on 07/08/25.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    @IBAction func didSelectFirstButton(_ sender: UIButton) {
        if let secureEntireView = SecureEntireViewController.secureEntireViewController() {
            self.present(secureEntireView, animated: true)
        }
    }

    @IBAction func didSelectSecondButton(_ sender: UIButton) {
        let secureViewController = SecureUIViewController()
        self.present(secureViewController, animated: true)
    }

    @IBAction func didSelectThirdButton(_ sender: UIButton) {
        if let secureSubViewsController = SecureSubViewsController.secureSubViewsController() {
            self.present(secureSubViewsController, animated: true)
        }
    }

    @IBAction func didSelectFourthButton(_ sender: UIButton) {
        self.present( XibViewController(), animated: true)
    }
}

