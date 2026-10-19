//
//  APIMetricsViewModel.swift
//  DebugLearning
//
//  Created by Ashish Awasthi on 06/10/26.
//

import Foundation
import Combine

/// Drives the API Metrics screen: triggers the network call via
/// NetworkMetricsService and publishes response/metrics state for the View.
@MainActor
final class APIMetricsViewModel: ObservableObject {
    @Published private(set) var metricsSummary: NetworkMetricsSummary?
    @Published private(set) var responseText: String = ""
    @Published private(set) var isFetching = false

    private let service: NetworkMetricsService

    init(service: NetworkMetricsService? = nil) {
        // Built inside the (MainActor-isolated) init body rather than as a
        // default argument, since default-argument expressions are evaluated
        // in the caller's context and NetworkMetricsService is MainActor-isolated.
        self.service = service ?? NetworkMetricsService()
    }

    func fetchMetrics() {
        isFetching = true
        service.fetch { [weak self] result, summary in
            guard let self else { return }
            self.isFetching = false
            switch result {
            case .success(let body):
                self.responseText = body
            case .failure(let error):
                self.responseText = "Error: \(error.localizedDescription)"
            }
            self.metricsSummary = summary
        }
    }
}
