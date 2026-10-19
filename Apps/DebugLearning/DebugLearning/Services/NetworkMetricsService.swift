//
//  NetworkMetricsService.swift
//  DebugLearning
//
//  Created by Ashish Awasthi on 06/10/26.
//

import Foundation

/// Makes a real network call against a public API using a URLSession wired up
/// with MetricsDelegate so timing metrics are captured for the request.
final class NetworkMetricsService {
    private let delegate = MetricsDelegate()
    private lazy var session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)

    /// Public, no-auth API used purely to demonstrate metrics collection.
    private var url = URL(string: "https://api.github.com/zen")!

    /// Fires a GET request and reports both the response body and the collected metrics.
    /// Completion is called on the main thread.
    func fetch(completion: @escaping (Result<String, Error>, NetworkMetricsSummary?) -> Void) {
        var latestMetrics: NetworkMetricsSummary?
        delegate.onMetrics = { summary in
            latestMetrics = summary
        }

        let task = session.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error {
                    completion(.failure(error), latestMetrics)
                    return
                }
                let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                completion(.success(body), latestMetrics)
            }
            print("URL: \(self.url)")
        }
        task.resume()
    }
}
