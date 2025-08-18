//
//  DocumentView.swift
//  HelperSwiftUIPOC
//
//  Created by Ashish Awasthi on 18/08/25.
//

import SwiftUI
import UIKit

struct DocumentView: View {
    
    @State private var showShareSheet = false
    let pdfURL: URL = URL(string: "https://ontheline.trincoll.edu/images/bookdown/sample-local-pdf.pdf")!
    let textToShare = "Check out this document!"
    let printFormatter = UISimpleTextPrintFormatter(text: "Document to print")
    var body: some View {
        VStack {
            Button("Share Content With Activity Controller") {
                self.showShareSheet = true
            }
        }
        .shareSheet(
            isPresented: $showShareSheet,
            activityItems: [textToShare,
                            printFormatter,
                            pdfURL,
                           ]
        )
        .padding()
    }
}



#Preview {
    ContentView()
}
