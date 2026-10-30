import SwiftUI

struct CrashDetailView: View {
    let report: CrashReport

    var body: some View {
        List {
            Section("Summary") {
                row("Type", report.type)
                row("Reason", report.reason)
                row("Date", report.date.formatted(date: .abbreviated, time: .standard))
                row("App version", report.appVersion)
                row("OS", report.osVersion)
            }
            Section("Stack trace") {
                ForEach(Array(report.stackTrace.enumerated()), id: \.offset) { _, line in
                    Text(line).font(.system(.caption, design: .monospaced))
                }
            }
        }
        .navigationTitle("Crash")
    }

    private func row(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value)
        }
    }
}
