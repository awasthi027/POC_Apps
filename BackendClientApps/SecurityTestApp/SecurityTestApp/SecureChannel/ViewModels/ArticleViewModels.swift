import Foundation
import Combine

final class ArticleListViewModel: ObservableObject {
    @Published var articles: [Article] = []
    @Published var status: String = "Articles not loaded"
    @Published var isRequestInProgress = false

    private let articleService: ArticleService
    private let authProvider: () -> SignedRequestContext?

    init(
        articleService: ArticleService,
        authProvider: @escaping () -> SignedRequestContext?
    ) {
        self.articleService = articleService
        self.authProvider = authProvider
    }

    func loadArticles() {
        guard !isRequestInProgress else { return }
        guard let auth = authProvider() else {
            status = "Connect and verify the secure channel first"
            return
        }

        isRequestInProgress = true
        status = "Loading articles..."

        articleService.loadArticles(auth: auth) { [weak self] result in
            guard let self = self else { return }
            self.isRequestInProgress = false

            switch result {
            case .failure(let error):
                self.status = "Load failed: \(error.localizedDescription)"
            case .success(let articles):
                self.articles = articles
                self.status = "Loaded \(articles.count) article(s)"
            }
        }
    }

    func loadArticlesIfNeeded() {
        guard articles.isEmpty else { return }
        loadArticles()
    }
}

final class ArticleCreateViewModel: ObservableObject {
    @Published var articleTitle: String = ""
    @Published var articleDescription: String = ""
    @Published var status: String = ""
    @Published var isRequestInProgress = false

    private let articleService: ArticleService
    private let authProvider: () -> SignedRequestContext?

    init(
        articleService: ArticleService,
        authProvider: @escaping () -> SignedRequestContext?
    ) {
        self.articleService = articleService
        self.authProvider = authProvider
    }

    func createArticle() {
        guard !isRequestInProgress else { return }
        guard let auth = authProvider() else {
            status = "Connect and verify the secure channel first"
            return
        }

        let title = articleTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = articleDescription.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !title.isEmpty, !description.isEmpty else {
            status = "Title and description are required"
            return
        }

        isRequestInProgress = true
        status = "Creating article..."

        articleService.createArticle(auth: auth, title: title, description: description) { [weak self] result in
            guard let self = self else { return }
            self.isRequestInProgress = false

            switch result {
            case .failure(let error):
                self.status = "Create failed: \(error.localizedDescription)"
            case .success(let statusCode):
                self.articleTitle = ""
                self.articleDescription = ""
                self.status = "Article created successfully (HTTP \(statusCode))"
            }
        }
    }
}

final class ArticleDetailViewModel: ObservableObject {
    @Published var article: Article?
    @Published var statusText = "Loading article..."
    @Published var isRefreshing = false

    let articleId: Int

    private let articleService: ArticleService
    private let authProvider: () -> SignedRequestContext?

    init(
        articleId: Int,
        articleService: ArticleService,
        authProvider: @escaping () -> SignedRequestContext?
    ) {
        self.articleId = articleId
        self.articleService = articleService
        self.authProvider = authProvider
    }

    func refreshArticle() {
        guard !isRefreshing else { return }
        guard let auth = authProvider() else {
            statusText = "Connect and verify the secure channel first"
            return
        }

        isRefreshing = true
        statusText = "Refreshing article #\(articleId)..."

        articleService.fetchArticleById(auth: auth, articleId: articleId) { [weak self] result in
            guard let self = self else { return }
            self.isRefreshing = false

            switch result {
            case .success(let loadedArticle):
                self.article = loadedArticle
                self.statusText = "Article refreshed successfully"
            case .failure(let error):
                self.statusText = "Failed to refresh: \(error.localizedDescription)"
            }
        }
    }
}

