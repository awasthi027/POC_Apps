//
//  ChQLPreviewController.swift
//  CoreHelpers
//
//  Created by Ashish Awasthi on 19/08/25.
//

import Foundation
import QuickLook

internal class CHQLPreviewController: QLPreviewController, QLPreviewControllerDataSource {
    class PreviewItem: NSObject, QLPreviewItem {
        let previewItemURL: URL?
        init(previewItemURL: URL?) {
            self.previewItemURL = previewItemURL
            super.init()
        }
    }

    let url: PreviewItem

    init(with url: URL, shouldAllowPrint: Bool = true) {
        self.url = PreviewItem(previewItemURL: url)
        self.iNavigationItem = EmptyRightBarButtonNavigationItem(shouldAllowPrint: shouldAllowPrint,
                                                                 title: url.lastPathComponent)
        super.init(nibName: nil, bundle: nil)
        self.dataSource = self
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.refreshCurrentPreviewItem()
    }

    // For an iPod Touch or an iPhone, the share button will be shown on the bottom tool bar
    // This will prevent the share button to be shown
    override var toolbarItems: [UIBarButtonItem]? {
        get { nil }
        set { print("Will not use new Value: \(String(describing: newValue))") }
    }

    // For an iPad, the share button will be shown on the top navigation bar
    // This will prevent the share button to be shown
    // This will also control the titleMenuProvider and documentProperties
    private class EmptyRightBarButtonNavigationItem: UINavigationItem {
        var shouldAllowPrint: Bool = true
        var actualTitleMenuProvider : (([UIMenuElement]) -> UIMenu?)?

        init(shouldAllowPrint: Bool, title: String) {
            self.shouldAllowPrint = shouldAllowPrint
            super.init(title: title)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

    @available(iOS 16.0, *)
        override var titleMenuProvider: (([UIMenuElement]) -> UIMenu?)? {
            get {
                if !shouldAllowPrint {
                    return nil
                }
                return actualTitleMenuProvider
            }
            set {
                if newValue != nil {
                    actualTitleMenuProvider = newValue
                }
            }
        }

        @available(iOS 16.0, *)
        override var documentProperties: UIDocumentProperties? {
            get{ nil }
            set{}
        }

        override func setRightBarButtonItems(_ items: [UIBarButtonItem]?, animated: Bool) { /*Override Method */ }

        override func setRightBarButton(_ item: UIBarButtonItem?, animated: Bool) { /*Override Method */ }

        override var rightBarButtonItem: UIBarButtonItem? {
            get { nil }
            set {
                self.setRightBarButton(nil, animated: false)
            }
        }
    }

    private let iNavigationItem: UINavigationItem
    override var navigationItem: UINavigationItem {
        self.iNavigationItem
    }

    public func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        1
    }

    public func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        self.url
    }
}
