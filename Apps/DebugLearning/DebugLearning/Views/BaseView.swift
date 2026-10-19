//
//  BaseView.swift
//  DebugLearning
//
//  Created by Ashish Awasthi on 06/10/26.
//

import SwiftUI
import SwiftData

/// Entry point screen: a plain list of destinations. Keep this view free of
/// any business logic — each row just navigates to its own feature screen.
struct BaseView: View {
    private enum Destination: String, CaseIterable, Identifiable {
        case addEntry = "Add Entry (Core Data)"
        case apiMetrics = "API Metrics"
        case accessibilityChecks = "Accessibility Checks"
        case launchTime = "Launch Time"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .addEntry: return "tray.and.arrow.down"
            case .apiMetrics: return "network"
            case .accessibilityChecks: return "accessibility"
            case .launchTime: return "stopwatch"
            }
        }
    }

    var body: some View {
        NavigationStack {
            List(Destination.allCases) { destination in
                NavigationLink {
                    view(for: destination)
                } label: {
                    Label(destination.rawValue, systemImage: destination.systemImage)
                }
            }
            .navigationTitle("DebugLearning")
        }
    }

    @ViewBuilder
    private func view(for destination: Destination) -> some View {
        switch destination {
        case .addEntry:
            ItemsListView()
        case .apiMetrics:
            APIMetricsView()
        case .accessibilityChecks:
            AccessibilityDemoView()
        case .launchTime:
            LaunchTimeView()
        }
    }
}

#Preview {
    BaseView()
        .modelContainer(for: Item.self, inMemory: true)
}
