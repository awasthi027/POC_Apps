//
//  ContentView.swift
//  SSLPinningTesting
//
//  Created by Ashish Awasthi on 17/06/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = SSLPinningDemoViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerCard
                    endpointCard
                    actionCard
                    resultsCard
                }
                .padding()
            }
            .navigationTitle("SSL Pinning Demo")
        }
    }

    private var headerCard: some View {
        GroupBox("What this sample validates") {
            VStack(alignment: .leading, spacing: 8) {
                Text("• A pinned iOS HTTPS call to `/api/secure/ping`")
                Text("• The backend’s `POST /api/client/verify` success path")
                Text("• The backend’s wrong-pin rejection path")
                Text(viewModel.statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var endpointCard: some View {
        GroupBox("Service endpoint") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Base URL", text: $viewModel.baseURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)

                Text("Default value `https://localhost:8443` works in the iOS Simulator when the Spring Boot service is running on your Mac.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var actionCard: some View {
        GroupBox("Run validations") {
            VStack(alignment: .leading, spacing: 12) {
                Button("Run full validation suite") {
                    viewModel.runValidationSuite()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isRunning)

                HStack {
                    Button("Pinned secure ping") {
                        viewModel.runSecurePing()
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isRunning)

                    Button("Verify correct pin") {
                        viewModel.runVerifyWithCorrectPin()
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isRunning)
                }

                HStack {
                    Button("Verify wrong pin") {
                        viewModel.runVerifyWithWrongPin()
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isRunning)

                    Button("Clear") {
                        viewModel.clearResults()
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isRunning && viewModel.results.isEmpty)
                }

                if viewModel.isRunning {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var resultsCard: some View {
        GroupBox("Results") {
            if viewModel.results.isEmpty {
                ContentUnavailableView(
                    "No results yet",
                    systemImage: "checklist",
                    description: Text("Run one of the validations to inspect the API responses.")
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.results) { result in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(result.title)
                                    .font(.headline)
                                Spacer()
                                Text(result.outcome.label)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(result.outcome == .success ? Color.green.opacity(0.18) : Color.red.opacity(0.18))
                                    .clipShape(Capsule())
                            }

                            Text(result.summary)
                                .font(.subheadline)

                            Text(result.detail)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(Color.secondary.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            Text(result.createdAt.formatted(date: .omitted, time: .standard))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
