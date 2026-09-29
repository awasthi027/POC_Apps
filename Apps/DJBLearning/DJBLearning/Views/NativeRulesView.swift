//
//  NativeRulesView.swift
//  DJBLearning
//
//  Tab 1: runs the hardcoded, native Swift jailbreak checks (see
//  JailbreakDetector.shared / JailbreakChecks/). This is the original
//  ContentView UI, extracted verbatim so it can sit alongside the
//  JS-rules-engine tab (JSRulesView).
//

import SwiftUI

struct NativeRulesView: View {
    @State private var detectionResult: JailbreakDetectionResult?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Device Security Check")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Hardcoded native Swift checks (JailbreakDetector + JailbreakChecks/).")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)

                Button(action: performDetection) {
                    if isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Analyzing...")
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Text("Scan Device Status")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)

                if let result = detectionResult {
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

                            // Risk Score
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Risk Score")
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text("\(result.riskScore)/100")
                                        .fontWeight(.bold)
                                        .foregroundColor(riskScoreColor(result.riskScore))
                                }

                                ProgressView(value: Double(result.riskScore), total: 100)
                                    .tint(riskScoreColor(result.riskScore))
                            }

                            Divider()

                            // Device Info
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("iOS Version:")
                                    Spacer()
                                    Text(result.iosVersion)
                                        .fontWeight(.semibold)
                                }

                                HStack {
                                    Text("Detection Method:")
                                    Spacer()
                                    Text(result.detectionMethod)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                }
                            }
                            .font(.subheadline)

                            Divider()

                            // Indicators
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Security Indicators (\(result.indicators.count))")
                                    .fontWeight(.semibold)
                                    .font(.subheadline)

                                ForEach(result.indicators, id: \.name) { indicator in
                                    IndicatorRow(indicator: indicator)
                                }
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
            .navigationTitle("Native Rules")
        }
    }

    private func performDetection() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let result = JailbreakDetector.shared.detectJailbreak()
            DispatchQueue.main.async {
                self.detectionResult = result
                self.isLoading = false
            }
        }
    }

    private func riskScoreColor(_ score: Int) -> Color {
        if score >= 60 {
            return .red
        } else if score >= 30 {
            return .orange
        } else {
            return .green
        }
    }
}

struct IndicatorRow: View {
    let indicator: JailbreakIndicator

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: indicator.isTriggered ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .foregroundColor(indicator.isTriggered ? .orange : .green)
                .font(.headline)

            VStack(alignment: .leading, spacing: 2) {
                Text(indicator.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                HStack(spacing: 8) {
                    Text(indicator.severity.description)
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(indicator.isTriggered ? "TRIGGERED" : "OK")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(indicator.isTriggered ? .orange : .green)
                }
            }

            Spacer()
        }
        .padding(10)
        .background(indicator.isTriggered ? Color.orange.opacity(0.1) : Color.green.opacity(0.1))
        .cornerRadius(6)
    }
}

#Preview {
    NativeRulesView()
}
