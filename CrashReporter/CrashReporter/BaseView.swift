import SwiftUI

struct BaseView: View {
    @StateObject private var viewModel: CrashListViewModel

    init(viewModel: CrashListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.reports.isEmpty {
                    ContentUnavailableView("No crashes", systemImage: "checkmark.shield",
                                           description: Text("Tap + to generate a crash, then relaunch the app."))
                } else {
                    List {
                        ForEach(viewModel.reports) { report in
                            NavigationLink(value: report) { CrashRow(report: report) }
                        }
                        .onDelete(perform: viewModel.remove)
                    }
                }
            }
            .navigationTitle("Crash Reports")
            .navigationDestination(for: CrashReport.self) { CrashDetailView(report: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !viewModel.reports.isEmpty {
                        Button("Clear", role: .destructive, action: viewModel.clearAll)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(CrashType.allCases) { type in
                            Button(type.rawValue) { viewModel.crash(type) }
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .onAppear(perform: viewModel.load)
    }
}

private struct CrashRow: View {
    let report: CrashReport

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(report.type).font(.headline)
            Text(report.reason).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            Text(report.date.formatted(date: .abbreviated, time: .standard))
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

#Preview {
    BaseView(viewModel: AppContainer.makeCrashListViewModel())
}
