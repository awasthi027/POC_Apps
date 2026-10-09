//
//  APIClient.swift
//  ArchLearning
//
//  Minimal, testable networking abstraction. Any data source depends on
//  this protocol rather than URLSession directly, so tests can inject a
//  stub/mock without touching the real network.
//

import Foundation

protocol APIClient: Sendable {
    func get<T: Decodable>(_ url: URL) async throws -> T
}

enum APIClientError: Error, Equatable {
    case invalidResponse
    case server(statusCode: Int)
}

struct URLSessionAPIClient: APIClient {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func get<T: Decodable>(_ url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIClientError.server(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }
}
