import SwiftUI

struct ArticleListView: View {
    @StateObject private var viewModel: ArticleListViewModel
    private let detailViewModelFactory: (Int) -> ArticleDetailViewModel

    init(
        viewModel: ArticleListViewModel,
        detailViewModelFactory: @escaping (Int) -> ArticleDetailViewModel
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.detailViewModelFactory = detailViewModelFactory
    }

    var body: some View {
        List {
            Section {
                Button(viewModel.isRequestInProgress ? "Refreshing..." : "Refresh Articles") {
                    viewModel.loadArticles()
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isRequestInProgress)

                Text(viewModel.status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Articles") {
                if viewModel.articles.isEmpty {
                    Text("No articles yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.articles) { article in
                        NavigationLink {
                            ArticleDetailView(viewModel: detailViewModelFactory(article.id))
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(article.title)
                                    .font(.headline)
                                Text("ID: \(article.id)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Articles")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadArticlesIfNeeded()
        }
    }
}

