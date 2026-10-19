//
//  APIMetricsView.swift
//  DebugLearning
//
//  Created by Ashish Awasthi on 06/10/26.
//

import SwiftUI
import Combine

/// Makes a real network call and displays the collected URLSessionTaskMetrics.
/// All networking/state logic lives in APIMetricsViewModel; this View only renders state.
struct APIMetricsView: View {
    @StateObject private var viewModel = APIMetricsViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: viewModel.fetchMetrics) {
                if viewModel.isFetching {
                    ProgressView()
                } else {
                    Label("Call API & Collect Metrics", systemImage: "network")
                }
            }
            .disabled(viewModel.isFetching)

            if !viewModel.responseText.isEmpty {
                Text("Response: \(viewModel.responseText)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let metricsSummary = viewModel.metricsSummary {
                Text(metricsSummary.description)
                    .font(.system(.footnote, design: .monospaced))
                    .padding()
                    .background(.secondary.opacity(0.1))
                    .cornerRadius(8)
            } else {
                Text("Tap the button above to make a network call and view timing metrics.")
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("API Metrics")
    }
}

#Preview {
    NavigationStack {
        APIMetricsView()
    }
}
