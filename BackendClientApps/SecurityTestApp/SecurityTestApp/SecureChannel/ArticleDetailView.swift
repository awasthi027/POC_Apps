import SwiftUI

struct ArticleDetailView: View {
    @StateObject private var viewModel: ArticleDetailViewModel

    init(viewModel: ArticleDetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Article #\(viewModel.articleId)")
                .font(.title3)
                .bold()

            if let article = viewModel.article {
                Text(article.title)
                    .font(.headline)
                Text(article.detailsText)
                    .foregroundStyle(.secondary)
            }

            Text(viewModel.statusText)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button(viewModel.isRefreshing ? "Refreshing..." : "Refresh by ID") {
                viewModel.refreshArticle()
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isRefreshing)

            Spacer()
        }
        .padding()
        .navigationTitle("Article Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if viewModel.article == nil {
                viewModel.refreshArticle()
            }
        }
    }
}
