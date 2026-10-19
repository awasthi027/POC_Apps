//
//  BaseView.swift
//  DeviceHealthLearning
//
//  Created by Ashish Awasthi on 30/09/26.
//

import SwiftUI

struct BaseView: View {
    @State private var viewModel = BaseViewModel()

    var body: some View {
        NavigationStack {
            // Re-render every second so the "time since" values tick.
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                List {
                    summarySection
                }
            }
            .navigationTitle(viewModel.title)
            .toolbar {
                Button("Refresh", systemImage: "arrow.clockwise") {
                    Task { await viewModel.refresh() }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .navigationDestination(for: HealthCategory.self) { category in
                HealthDetailView(category: category, viewModel: viewModel)
            }
        }
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear { viewModel.onDisappear() }
    }

    private var summarySection: some View {
        Section {
            ForEach(HealthCategory.allCases) { category in
                NavigationLink(value: category) {
                    HealthSummaryRow(summary: viewModel.summary(for: category))
                }
            }
        } header: {
            HStack {
                Text("Status")
                Spacer()
                StatusBadge(status: viewModel.overallStatus)
            }
        }
    }

}

struct HealthItemRow: View {
    let item: HealthItem

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(item.name).font(.subheadline.monospaced())
                if let footnote = item.footnote {
                    Text(footnote).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(item.value ?? "nil").foregroundStyle(item.value == nil ? .secondary : .primary)
        }
    }
}

private struct HealthSummaryRow: View {
    let summary: HealthSummary

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(summary.status.color)
                .frame(width: 14, height: 14)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(summary.name).font(.headline)
                    Spacer()
                    Text(summary.status.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(summary.status.color)
                }
                ForEach(summary.reasons, id: \.self) { reason in
                    Text(reason).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct StatusBadge: View {
    let status: HealthStatus

    var body: some View {
        Text(status.title)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(status.color.opacity(0.2), in: Capsule())
            .foregroundStyle(status.color)
    }
}

private extension HealthStatus {
    var color: Color {
        switch self {
        case .green: return .green
        case .orange: return .orange
        case .red: return .red
        }
    }
}

#Preview {
    BaseView()
}
