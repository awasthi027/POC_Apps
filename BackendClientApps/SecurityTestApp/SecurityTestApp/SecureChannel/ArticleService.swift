import Foundation

private struct CreateArticlePayload: Encodable {
    let title: String
    let description: String
}

final class ArticleService {
    private let requestExecutor: SignedRequestExecutor

    init(requestExecutor: SignedRequestExecutor) {
        self.requestExecutor = requestExecutor
    }

    func loadArticles(
        auth: SignedRequestContext,
        completion: @escaping (Result<[Article], Error>) -> Void
    ) {
        requestExecutor.execute(auth: auth, method: "GET", path: "/articles", bodyData: nil) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let value):
                do {
                    completion(.success(try self.decodeArticles(from: value.data)))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }

    func createArticle(
        auth: SignedRequestContext,
        title: String,
        description: String,
        completion: @escaping (Result<Int, Error>) -> Void
    ) {
        guard let bodyData = try? JSONEncoder().encode(CreateArticlePayload(title: title, description: description)) else {
            completion(.failure(NSError(domain: "ArticleService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not encode article payload"])))
            return
        }

        requestExecutor.execute(auth: auth, method: "POST", path: "/articles", bodyData: bodyData) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let value):
                completion(.success(value.response.statusCode))
            }
        }
    }

    func fetchArticleById(
        auth: SignedRequestContext,
        articleId: Int,
        completion: @escaping (Result<Article, Error>) -> Void
    ) {
        requestExecutor.execute(auth: auth, method: "GET", path: "/articles/\(articleId)", bodyData: nil) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let value):
                do {
                    completion(.success(try self.decodeSingleArticle(from: value.data)))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }

    private func decodeArticles(from data: Data) throws -> [Article] {
        if let items = try? JSONDecoder().decode([Article].self, from: data) {
            return items
        }

        struct WrappedArticles: Decodable { let articles: [Article] }
        if let wrapped = try? JSONDecoder().decode(WrappedArticles.self, from: data) {
            return wrapped.articles
        }

        throw NSError(domain: "ArticleService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not decode article list"])
    }

    private func decodeSingleArticle(from data: Data) throws -> Article {
        if let article = try? JSONDecoder().decode(Article.self, from: data) {
            return article
        }

        struct WrappedArticle: Decodable { let article: Article }
        if let wrapped = try? JSONDecoder().decode(WrappedArticle.self, from: data) {
            return wrapped.article
        }

        throw NSError(domain: "ArticleService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not decode article"])
    }
}
