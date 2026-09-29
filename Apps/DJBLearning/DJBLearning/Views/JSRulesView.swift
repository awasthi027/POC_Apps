//
//  JSRulesView.swift
//  DJBLearning
//
//  Tab 2: executes the dynamic, JS-based rule set (decoded_payload.js) via
//  JSJailbreakChecker, which runs it inside JavaScriptCore and bridges its
//  `native_*` calls to real implementations (see JSNativeBridge /
//  NativeChecks). Completely independent from the hardcoded Swift checks in
//  NativeRulesView.
//

import SwiftUI

struct JSRulesView: View {
    @State private var result: JSJailbreakResult?
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showLogs = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Dynamic Rules Engine")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Executes decoded_payload.js in a JavaScriptCore context, bridging native_* calls to real Darwin/Foundation APIs.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)

                Button(action: runJSChecks) {
                    if isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Running JS Engine...")
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Text("Run JS Rule Engine")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                if let result {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // Status Header
                            HStack(spacing: 12) {
                                Image(systemName: result.isJailbroken ? "exclamationmark.triangle.fill" : "checkmark.shield.fill")
                                    .font(.title)
                                    .foregroundColor(result.isJailbroken ? .red : .green)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Status")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text(result.isJailbroken ? "⚠️ Device Appears Jailbroken" : "✅ Device is Secure")
                                        .font(.headline)
                                        .foregroundColor(result.isJailbroken ? .red : .green)
                                }

                                Spacer()
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)

                            if let ruleSetId = result.ruleSetId {
                                HStack {
                                    Text("Rule Set:")
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text(ruleSetId)
                                        .font(.caption)
                                }
                                .font(.subheadline)
                            }

                            if !result.failedReasonCodes.isEmpty {
                                HStack {
                                    Text("Failed Reason Codes:")
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text(result.failedReasonCodes.map(String.init).joined(separator: ", "))
                                        .foregroundColor(.orange)
                                }
                                .font(.subheadline)
                            }

                            Divider()

                            // Checks
                            VStack(alignment: .leading, spacing: 12) {
                                Text("JS Rule Checks (\(result.checks.count))")
                                    .fontWeight(.semibold)
                                    .font(.subheadline)

                                ForEach(result.checks) { check in
                                    JSCheckRow(check: check)
                                }
                            }

                            if !result.exceptions.isEmpty {
                                Divider()
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Exceptions Reported")
                                        .fontWeight(.semibold)
                                        .foregroundColor(.red)
                                    ForEach(Array(result.exceptions.enumerated()), id: \.offset) { _, message in
                                        Text(message)
                                            .font(.caption2)
                                            .foregroundColor(.red)
                                    }
                                }
                            }

                            Divider()

                            DisclosureGroup(isExpanded: $showLogs) {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(result.logLines) { line in
                                        Text("[\(line.level)] \(line.message)")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding(.top, 4)
                            } label: {
                                Text("Engine Log (\(result.logLines.count) lines)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding()
                    }
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("JS Rules")
        }
    }

    private func runJSChecks() {
        isLoading = true
        errorMessage = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let outcome = JSJailbreakChecker.shared.run()
            DispatchQueue.main.async {
                switch outcome {
                case .success(let result):
                    self.result = result
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
                self.isLoading = false
            }
        }
    }
}

struct JSCheckRow: View {
    let check: JSCheckEntry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: check.passed ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundColor(check.passed ? .green : .orange)
                .font(.headline)

            Text(check.name)
                .font(.subheadline)
                .fontWeight(.semibold)

            Spacer()

            Text(check.passed ? "OK" : "FAILED")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(check.passed ? .green : .orange)
        }
        .padding(10)
        .background(check.passed ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
        .cornerRadius(6)
    }
}

#Preview {
    JSRulesView()
}
