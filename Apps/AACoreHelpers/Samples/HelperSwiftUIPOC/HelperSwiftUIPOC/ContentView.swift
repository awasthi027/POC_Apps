//
//  ContentView.swift
//  HelperSwiftUIPOC
//
//  Created by Ashish Awasthi on 12/08/25.
//

import SwiftUI
import WebKit

struct ContentView: View {

    @State private var text: String = ""
    @State private var textViewText: String = ""

    var body: some View {
        VStack {
            TextField("Enter Text", text: $text)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))

            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text("Your text will appear here")
                        .foregroundColor(.gray)
                        .padding(.leading, 4)
                }
                TextEditor(text: self.$textViewText)
                    .padding(8)
                    .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 150)
                    .background(RoundedRectangle(cornerRadius: 8).stroke(Color.blue, lineWidth: 1))
            }

            CustomWKWebView(webViewStatus: .editable,
                            url: URL(string: "https://www.google.com")!)
                .frame(maxHeight: 450)
                .padding(.horizontal, 20)
            Button {

            } label: {
                NavigationLink(value: ControllerNavigation.swizzleControllers) {
                    Text("Swizzle Controllers")
                }
            }
            .accessibilityIdentifier("swizzle Controller")
            .padding(.top, 20)

            Button {

            } label: {
                NavigationLink(value: ControllerNavigation.storyBoardController) {
                    Text("Story Swizzle Controller")
                }
            }
            .accessibilityIdentifier("swizzleControllers")
            .padding(.top, 20)
        }
        .padding()
        .navigationDestination(for: ControllerNavigation.self) { item in
            switch item {
            case .swizzleControllers:
                DocumentView()
            case .storyBoardController:
                SwiftViewControllerWrapper()
            }
        }
        .navigationBarTitle("Home", displayMode: .inline)
        .navigationViewStyle(.automatic)
        .onAppear() {
        }
    }
}



#Preview {
    ContentView()
}

