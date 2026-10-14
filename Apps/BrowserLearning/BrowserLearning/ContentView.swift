//
//  ContentView.swift
//  BrowserLearning
//
//  Created by Ashish Awasthi on 13/10/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                BrowserView(
                    browserViewModel: BrowserViewModel(opener: SystemURLOpener())
                )
            }
            .tabItem {
                Label("Browser", systemImage: "safari")
            }

            NavigationStack {
                BrowserSamplePageView(
                    viewModel: BrowserSamplePageViewModel(opener: SystemURLOpener())
                )
            }
            .tabItem {
                Label("Browser Links", systemImage: "doc.text")
            }

            NavigationStack {
                URLLauncherView(
                    viewModel: URLLauncherViewModel(opener: SystemURLOpener())
                )
            }
            .tabItem {
                Label("Open URL", systemImage: "link")
            }
        }
    }
}

#Preview {
    ContentView()
}
