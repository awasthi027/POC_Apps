//
//  URLLauncherView.swift
//  ai-concept-learning
//
//  Dedicated tab for opening a user-entered URL in the system browser.
//

import SwiftUI

struct URLLauncherView: View {

    @StateObject var viewModel: URLLauncherViewModel

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
        Form {
            Section("Enter URL") {
                TextField("example.com", text: $viewModel.targetURLString)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .accessibilityIdentifier("urlLauncherField")
                Button("Open URL") {
                    Task {
                        await viewModel.openEnteredURL()
                    }
                }
                .accessibilityIdentifier("urlLauncherButton")
            }
        }
        .navigationTitle("Open URL")
        .alert("Unable to open URL", isPresented: isShowingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

#Preview {
    NavigationStack {
        URLLauncherView(
            viewModel: URLLauncherViewModel(opener: SystemURLOpener())
        )
    }
}
