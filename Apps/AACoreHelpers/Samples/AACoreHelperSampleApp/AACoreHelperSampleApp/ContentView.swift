//
//  ContentView.swift
//  AACoreHelperSampleApp
//
//  Created by Ashish Awasthi on 06/03/25.
//

import SwiftUI


struct ContentView: View {
    @State private var text: String = ""
    @State private var showingPasteOptions: Bool = false
    var manager =  CrossAppEventManager()
    var body: some View {
        VStack {

            Button("Paste") {
                showingPasteOptions = true
            }
            .padding()
        }
        .padding()
        .confirmationDialog("Paste Options", isPresented: $showingPasteOptions) {
            Button("Paste from Clipboard") {
                pasteFromClipboard()
            }
            Button("Cancel", role: .cancel) {}
        }.onAppear() {

        }
    }

    func pasteFromClipboard() {
        self.text = UIPasteboard.general.string ?? ""
    }
}


#Preview {
    ContentView()
}
