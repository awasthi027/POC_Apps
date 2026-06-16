import SwiftUI

struct ArticleCreateView: View {
    @StateObject private var viewModel: ArticleCreateViewModel

    init(viewModel: ArticleCreateViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        Form {
            Section("Article Details") {
                TextField("Article title", text: $viewModel.articleTitle)
                    .textInputAutocapitalization(.sentences)
                TextField("Article description", text: $viewModel.articleDescription, axis: .vertical)
                    .lineLimit(4, reservesSpace: true)
                    .textInputAutocapitalization(.sentences)
            }

            Section {
                Button(viewModel.isRequestInProgress ? "Creating..." : "Create Article") {
                    viewModel.createArticle()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isRequestInProgress)
            }

            if !viewModel.status.isEmpty {
                Section("Status") {
                    Text(viewModel.status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Create Article")
        .navigationBarTitleDisplayMode(.inline)
    }
}

