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

    var documentInteractionController: UIDocumentInteractionController?

    class func swiftViewController() -> SwiftViewController?  {
        return UIStoryboard.main.instantiateViewController(withIdentifier:
                                                            String(describing: SwiftViewController.self)) as? SwiftViewController
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func previewDocument(_ sender: Any) {

        let filePath = Bundle.main.path(forResource: "PDF_Extension_check", ofType: "pdf")
        let fileURL = URL(fileURLWithPath: filePath!)
        documentInteractionController = UIDocumentInteractionController(url: fileURL)
        documentInteractionController?.delegate = self
        documentInteractionController?.presentPreview(animated: true)
    }

    @IBAction func openDocument(_ sender: UIButton) {
        let filePath = Bundle.main.path(forResource: "PDF_Extension_check", ofType: "pdf")
        let fileURL = URL(fileURLWithPath: filePath!)

        documentInteractionController = UIDocumentInteractionController(url: fileURL)
        documentInteractionController?.delegate = self
        documentInteractionController?.presentOpenInMenu(from: sender.frame, in: self.view, animated: true)
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
    
    @IBAction func printPDF(_ sender: Any) {
        let printInteractionController = UIPrintInteractionController.shared
        let pdfFilePath = Bundle.main.path(forResource: "PDF_Extension_check", ofType: "pdf")
        let fileURL = URL(fileURLWithPath: pdfFilePath!)
        let pdfData = try! Data(contentsOf: fileURL)

        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.jobName = "Ninjas Print Job"
        printInfo.orientation = .portrait
        printInfo.outputType = .general
        printInfo.duplex = .longEdge

        printInteractionController.printInfo = printInfo
        printInteractionController.showsNumberOfCopies = true
        printInteractionController.showsPaperSelectionForLoadedPapers = true

        printInteractionController.printingItem = pdfData

        printInteractionController.present(animated: true) { (controller, status, err) in
            let cntr = controller
            print("Status = \(status)")
            print("err = \(String(describing: err))")
        }
    }

}

extension SwiftViewController: UIDocumentInteractionControllerDelegate {
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return self
    }

    // Options menu presented/dismissed on document.  Use to set up any HI underneath.
    func documentInteractionControllerWillPresentOptionsMenu(_ controller: UIDocumentInteractionController) {
        print("documentInteractionControllerWillPresentOptionsMenu")
    }

    func documentInteractionControllerDidDismissOptionsMenu(_ controller: UIDocumentInteractionController) {
        print("documentInteractionControllerDidDismissOptionsMenu")
    }
}

extension SwiftViewController: UIPrintInteractionControllerDelegate {
    func printInteractionControllerParentViewController(_ printInteractionController: UIPrintInteractionController) -> UIViewController? {
        return self
    }

    func printInteractionController(_ printInteractionController: UIPrintInteractionController, choosePaper paperList: [UIPrintPaper]) -> UIPrintPaper {
        let paperSize = CGSize(width: 8.5 * 72.0, height: 11.0 * 72.0)
        return UIPrintPaper.bestPaper(forPageSize: paperSize, withPapersFrom: paperList)
    }

    func printInteractionControllerWillPresentPrinterOptions(_ printInteractionController: UIPrintInteractionController) {
        print("will present printer options")
    }

    func printInteractionControllerDidPresentPrinterOptions(_ printInteractionController: UIPrintInteractionController) {
        print("did present printer options")
    }

    func printInteractionControllerWillDismissPrinterOptions(_ printInteractionController: UIPrintInteractionController) {
        print("will dismiss printer options")
    }

    func printInteractionControllerDidDismissPrinterOptions(_ printInteractionController: UIPrintInteractionController) {
        print("did dismiss printer options")
    }

    func printInteractionControllerWillStartJob(_ printInteractionController: UIPrintInteractionController) {
        print("will start job")
    }

    func printInteractionControllerDidFinishJob(_ printInteractionController: UIPrintInteractionController) {
        print("Did Finish Job")
    }

    func printInteractionController(_ printInteractionController: UIPrintInteractionController, cutLengthFor paper: UIPrintPaper) -> CGFloat {
        return paper.printableRect.width
    }

    func printInteractionController(_ printInteractionController: UIPrintInteractionController, chooseCutterBehavior availableBehaviors: [Any]) -> UIPrinter.CutterBehavior {
        return .cutAfterEachPage
    }
}
