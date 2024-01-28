//
//  UILayoutViewScreen.swift
//  UITestPOC
//
//  Created by Ashish Awasthi on 22/01/24.
//

import SwiftUI

struct UILayoutViews: View {
    @State var searchText: String = ""
    @State private var isSharePresented: Bool = false
    @State private var showActionSheet = false
    var body: some View {
        /// Test all usevle for test case
        VStack {
            Button {
                self.isSharePresented = true
            } label: {
                Text("Open ActivityController")
            }
            .accessibilityIdentifier("shareActionButton")

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
            print("Dismiss")
        }, content: {
            ActivityViewController(activityItems: [URL(string: "https://www.apple.com")!])
        })
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
