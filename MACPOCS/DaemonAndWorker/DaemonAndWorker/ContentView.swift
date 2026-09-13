//
//  ContentView.swift
//  DaemonAndWorker
//
//  Created by Ashish Awasthi on 27/08/26.
//

import SwiftUI

struct ContentView: View {
    @State private var log: [String] = []
    @State private var workerName = "Worker-A"
    private let client = LearningDaemonClient()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daemon & Worker — Learning Demo")
                .font(.title2).bold()
            Text("This app is a client (worker) talking to LearningDaemon, a separate, always-on process managed by launchd — not a child process of this app.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Worker identity", selection: $workerName) {
                Text("Worker-A").tag("Worker-A")
                Text("Worker-B").tag("Worker-B")
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 240)

            HStack {
                Button("Ping Daemon") { ping() }
                Button("Submit Job as \(workerName)") { submitJob() }
                Button("Crash Daemon", role: .destructive) { crash() }
            }

            Divider()

            List(log.reversed(), id: \.self) { line in
                Text(line).font(.system(.caption, design: .monospaced))
            }
            .frame(minHeight: 220)
        }
        .padding()
        .frame(minWidth: 520, minHeight: 440)
    }

    private func append(_ line: String) {
        DispatchQueue.main.async { log.append(line) }
    }

    private func ping() {
        client.ping { result in
            switch result {
            case .success(let r):
                append("PING → daemon pid \(r.pid), uptime \(Int(r.uptime))s, jobs handled so far: \(r.jobCount)")
            case .failure(let error):
                append("PING failed — is LearningDaemon installed/loaded? (\(error.localizedDescription))")
            }
        }
    }

    private func submitJob() {
        client.submitJob(workerName: workerName) { result in
            switch result {
            case .success(let r):
                append("\(workerName) → job #\(r.jobNumber) accepted by daemon pid \(r.pid)")
            case .failure(let error):
                append("submitJob failed — (\(error.localizedDescription))")
            }
        }
    }

    private func crash() {
        append("Telling daemon to exit — ping again in a moment; launchd should hand you back a new pid.")
        client.crashDaemon()
    }
}

#Preview {
    ContentView()
}
