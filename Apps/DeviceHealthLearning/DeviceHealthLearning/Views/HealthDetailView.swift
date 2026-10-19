//
//  HealthDetailView.swift
//  DeviceHealthLearning
//
//  Detail page for one summary row (Battery / Network / Network Speed / Network Restrictions).
//  Pushed from BaseView when that row is tapped.
//

import SwiftUI

struct HealthDetailView: View {
    let category: HealthCategory
    let viewModel: BaseViewModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            List {
                statusSection
                Section("Details") {
                    ForEach(viewModel.items(for: category)) {
                        HealthItemRow(item: $0)
                    }
                }
                if !viewModel.events(for: category).isEmpty {
                    Section("Events") {
                        ForEach(viewModel.events(for: category)) {
                            HealthEventRow(event: $0)
                        }
                    }
                }
            }
        }
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Refresh", systemImage: "arrow.clockwise") {
                Task { await viewModel.refresh(category) }
            }
        }
        .refreshable {
            await viewModel.refresh(category)
        }
    }

    private var statusSection: some View {
        let summary = viewModel.summary(for: category)
        return Section {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(summary.reasons, id: \.self) { reason in
                    Label(reason, systemImage: "circle.fill")
                        .labelStyle(.titleOnly)
                        .font(.subheadline)
                }
            }
        } header: {
            HStack {
                Text("Status")
                Spacer()
                StatusBadge(status: summary.status)
            }
        }
    }
}

private struct HealthEventRow: View {
    let event: HealthEvent

    var body: some View {
        VStack(alignment: .leading) {
            Text(event.name).font(.subheadline.monospaced())
            Text("\(event.detail) · \(event.date.formatted(date: .omitted, time: .standard))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        HealthDetailView(category: .battery, viewModel: BaseViewModel())
    }
}
