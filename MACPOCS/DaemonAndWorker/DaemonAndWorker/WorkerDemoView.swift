//
//  WorkerDemoView.swift
//  DaemonAndWorker
//
//  Standalone worker demo — deliberately has nothing to do with the Daemon
//  tab. No XPC, no launchd, no Mach service. Each button tap spawns a real,
//  independent OS process via Process() that does one small job and exits.
//
//  The point to watch: every run gets a brand-new pid, and once the process
//  exits, that pid is gone for good — there's nothing resident to reconnect
//  to and nothing for launchd to restart, unlike the daemon.
//

import SwiftUI
import Combine

struct WorkerRun: Identifiable {
    let id = UUID()
    let jobLabel: String
    var pid: Int32?
    var output: [String] = []
    var finishedAt: Date?
    var isRunning: Bool { finishedAt == nil }
}

@MainActor
final class WorkerDemoModel: ObservableObject {
    @Published var runs: [WorkerRun] = []

    func runJob(label: String) {
        let run = WorkerRun(jobLabel: label)
        let index = runs.count
        runs.append(run)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        // The worker's entire life: print its own pid, pretend to work for
        // a second, print that it's done, then the process exits on its own.
        process.arguments = ["-c", "echo worker pid $$; sleep 1; echo \(label) finished its job"]

        let pipe = Pipe()
        process.standardOutput = pipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor [weak self] in
                self?.appendOutput(text, toRunAt: index)
            }
        }

        process.terminationHandler = { [weak self] proc in
            pipe.fileHandleForReading.readabilityHandler = nil
            Task { @MainActor [weak self] in
                self?.finish(runAt: index, pid: proc.processIdentifier)
            }
        }

        do {
            try process.run()
            runs[index].pid = process.processIdentifier
        } catch {
            runs[index].output.append("failed to launch: \(error.localizedDescription)")
            runs[index].finishedAt = Date()
        }
    }

    private func appendOutput(_ text: String, toRunAt index: Int) {
        guard runs.indices.contains(index) else { return }
        let lines = text.split(separator: "\n").map(String.init)
        runs[index].output.append(contentsOf: lines)
    }

    private func finish(runAt index: Int, pid: Int32) {
        guard runs.indices.contains(index) else { return }
        runs[index].pid = pid
        runs[index].finishedAt = Date()
    }
}

struct WorkerDemoView: View {
    @StateObject private var model = WorkerDemoModel()
    @State private var nextJobNumber = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Worker — Learning Demo")
                .font(.title2).bold()
            Text("Each tap spawns a brand-new, short-lived process — a worker — that does one job and exits. There's no daemon involved here: nothing stays resident, nothing gets restarted. Compare the pids below to how the Daemon tab's pid stays constant across requests.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Run 1 Job") { launch(count: 1) }
                Button("Run 3 Jobs Concurrently") { launch(count: 3) }
            }

            Divider()

            List(model.runs.reversed()) { run in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(run.jobLabel).bold()
                        Text(run.isRunning ? "running…" : "exited")
                            .foregroundStyle(run.isRunning ? .orange : .green)
                        if let pid = run.pid {
                            Text("pid \(pid)").font(.system(.caption, design: .monospaced))
                        }
                    }
                    ForEach(Array(run.output.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .frame(minWidth: 520, minHeight: 440)
    }

    private func launch(count: Int) {
        for _ in 0..<count {
            model.runJob(label: "Job-\(nextJobNumber)")
            nextJobNumber += 1
        }
    }
}

#Preview {
    WorkerDemoView()
}
