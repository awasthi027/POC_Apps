//
//  SwiftViewController.swift
//  HelperSwiftUIPOC
//
//  Created by Ashish Awasthi on 18/08/25.
//

import UIKit

extension UIStoryboard {
    // Main storyboard
    static var main: UIStoryboard {
        return UIStoryboard(name: "Main", bundle: nil)
    }

    func instantiateViewController<T>(withIdentifier identifier: T.Type) -> T? where T: UIViewController {
        let className = String(describing: identifier)
        return self.instantiateViewController(withIdentifier: className) as? T
    }
}

class SwiftViewController: UIViewController {

    class func swiftViewController() -> SwiftViewController?  {
        return UIStoryboard.main.instantiateViewController(withIdentifier:
                                                            String(describing: SwiftViewController.self)) as? SwiftViewController
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func goToAppleSite(_ sender: UIButton) {
        let url = URL(string: "https://www.apple.com")!
        let textToShare = "Check out Apple's website"
        let printFormatter = UISimpleTextPrintFormatter(text: "Document to print")
        // Create activity items array with multiple representations
        let items: [Any] = [textToShare, url,printFormatter]

        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)

        // For iPad support
        if let popoverController = vc.popoverPresentationController {
            popoverController.sourceView = sender
            popoverController.sourceRect = sender.bounds
        }

        present(vc, animated: true)
    }

}
