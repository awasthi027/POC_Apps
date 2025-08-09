//
//  SecureSubViewsController.swift
//  ScreenProtector
//
//  Created by Ashish Awasthi on 08/08/25.
//

import UIKit
import WebKit
import SecureScreen

class SecureSubViewsController: UIViewController {

    @IBOutlet weak var secureView: CustomSecureView!
    @IBOutlet weak var wkWebView: WKWebView!

    class func secureSubViewsController() -> SecureSubViewsController?  {
        return UIStoryboard.main.instantiateViewController(withIdentifier: String(describing: SecureSubViewsController.self)) as? SecureSubViewsController
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        wkWebView.load(URLRequest(url: URL(string: "https://www.google.com")!))
    }

    override func viewWillAppear(_ animated: Bool) {
         super.viewWillAppear(animated)
    }
}
