//
//  BrowserSamplePageView.swift
//  ai-concept-learning
//
//  Displays a local HTML page with browser-specific sample links.
//

import SwiftUI

struct BrowserSamplePageView: View {

    @StateObject var viewModel: BrowserSamplePageViewModel

    private var isShowingError: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.errorMessage = nil
                }
            }
        )
    }

    var body: some View {
        BrowserSampleWebView(htmlContent: viewModel.htmlContent) { selectedURL in
            Task {
                await viewModel.openTargetURL(selectedURL)
            }
        }
        .navigationTitle("Browser Links")
        .onAppear {
            viewModel.loadPage()
        }
        .alert("Unable to open browser link", isPresented: isShowingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

#Preview {
    NavigationStack {
        BrowserSamplePageView(
            viewModel: BrowserSamplePageViewModel(opener: SystemURLOpener())
        )
    }
}
