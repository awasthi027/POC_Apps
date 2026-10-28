//
//  HomeView.swift
//  WKWebViewLearning
//
//  Created by Ashish Awasthi on 30/09/26.
//

import SwiftUI

/// A simple model representing a selectable URL example shown in the list.
struct URLExample: Identifiable {
    let id = UUID()
    let title: String
    let urlString: String
}

struct HomeView: View {
    private let examples: [URLExample] = [
        URLExample(title: "Google", urlString: "https://www.google.com"),
        URLExample(title: "Omnissa", urlString: "https://www.omnissa.com"),
        URLExample(title: "Apple", urlString: "https://www.apple.com"),
        URLExample(title: "iOS What's New", urlString: "https://developer.apple.com/ios/whats-new")
    ]

    @State private var selectedExample: URLExample?

    var body: some View {
        NavigationStack {
            List(examples) { example in
                Button(example.title) {
                    selectedExample = example
                }
            }
            .navigationTitle("Home")
        }
        .sheet(item: $selectedExample) { example in
            if let url = URL(string: example.urlString) {
                NavigationStack {
                    HubWebView(
                        url: url,
                        title: example.title,
                        strings: HubWebViewStrings(dismissButtonTitle: "Done"),
                        showsNavigationActions: false)
                }
            }
        }
    }
}

#Preview {
    HomeView()
}
