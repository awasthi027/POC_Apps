//
//  UILayoutViewScreen.swift
//  UITestPOC
//
//  Created by Ashish Awasthi on 22/01/24.
//

import SwiftUI

enum PDFFileAction: Int {
    case sharePDF
    case openActivityController
}

struct UILayoutViews: View {
    @State var searchText: String = ""
    @State private var isSharePresented: Bool = false
    @State private var showActionSheet = false
    @State var pdfAction: PDFFileAction = .sharePDF

    var body: some View {
        /// Test all usevle for test case
        VStack {
            Button {
                self.pdfAction = .openActivityController
                self.isSharePresented = true
            } label: {
                Text("Open ActivityController")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("shareActionButton")

            Button {
                self.pdfAction = .sharePDF
                self.isSharePresented = true
            } label: {
                Text("Share PDF file")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("sharePDFButton")

            TextField("Type text", text: self.$searchText)
                .accessibilityIdentifier("searchTextField")

            Button("Show Action Sheet") {
                self.showActionSheet = true
            }
            .accessibilityIdentifier("actionSheetButton")
            .actionSheet(isPresented: self.$showActionSheet) {
                ActionSheet(
                    title: Text("Select a color"),
                    buttons: [
                        .default(Text("Red")) {
                            print("SelectedColor: Red")
                        },

                            .default(Text("Green")) {
                                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2) {
                                    self.isSharePresented = true
                                    print("SelectedColor: After Green")
                                }
                                print("SelectedColor: Green")
                            },

                            .default(Text("Blue")) {
                                print("SelectedColor: Blue")
                            },
                    ]
                )
            }
        }
        .sheet(isPresented: self.$isSharePresented, onDismiss: {
            self.isSharePresented = false
            print("Dismiss")
        }, content: {
            self.pdfActionView()
        })
    }

    func pdfActionView() -> some View {
        switch self.pdfAction {
        case .sharePDF:
            let filePath = Bundle.main.path(forResource: "PDF_Extension_check", ofType: "pdf")
            let fileURL = URL(fileURLWithPath: filePath!)
            let items = [fileURL]
            let vc = ActivityViewController(activityItems: items)
          return vc
        case .openActivityController:
           return ActivityViewController(activityItems: [URL(string: "https://www.apple.com")!])
        }
    }
}

#Preview {
    UILayoutViews()
}

import UIKit
import SwiftUI

struct ActivityViewController: UIViewControllerRepresentable {

    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityViewController>) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityViewController>) {}

}

/*
 let filePath = Bundle.main.path(forResource: "PDF_Extension_check", ofType: "pdf")
 //let filePath = Bundle.main.path(forResource: "fileToEncrypt", ofType: "doc")
 // let filePath = Bundle.main.path(forResource: “airwatch”, ofType: “jpg”)
 let fileURL = URL(fileURLWithPath: filePath!)
 let items = [fileURL]
 let vc = UIActivityViewController(activityItems: items, applicationActivities: [])
 vc.popoverPresentationController?.sourceView = sender
 present(vc, animated: true)

 */
