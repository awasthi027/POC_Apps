//
//  ContentView.swift
//  ServerSSLPinningApp
//
//  Created by Ashish Awasthi on 18/06/26.
//

import SwiftUI
//baseURLString: String = "https://localhost:8443",
//certificateResourceName: String = "local-host"

struct ContentView: View {
    @State private var statusMessage = "On launch: fetch /server-pins (system trust) and store. Then validate /server-pin against them."
    @State private var isLoading = false
    @State private var baseURL = "https://server-ssl-pinning-production.up.railway.app"
    @State private var certificateName = "railways"

    @EnvironmentObject private var pinStore: PinStore

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "lock.shield")
                    .imageScale(.large)
                    .foregroundStyle(.tint)

                Text("Server SSL Pinning")
                    .font(.headline)

                Text("Spring Boot service • /api/pinning")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("Base URL", text: $baseURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)

                TextField("Certificate Name (.cer)", text: $certificateName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 12) {
                    Button {
                        Task { await provisionPins() }
                    } label: {
                        Text("Fetch /server-pins")
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading)

                    Button {
                        Task { await validateServerPin() }
                    } label: {
                        Text("Validate /server-pin")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading || pinStore.snapshot.isEmpty)
                }

                if isLoading {
                    ProgressView()
                }

                Text(statusMessage)
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)

                storedPinsSection
            }
            .padding()
        }

    }

    /// Shows pins currently stored against each host.
    private var storedPinsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            Text("Stored Pins (by host)")
                .font(.headline)

            if pinStore.snapshot.isEmpty {
                Text("No pins stored yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(pinStore.snapshot.keys.sorted(), id: \.self) { host in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(host)
                            .font(.subheadline.bold())
                        ForEach(pinStore.snapshot[host] ?? [], id: \.self) { pin in
                            Text(pin)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func makeService() -> PinnedAPIDemoService {
        PinnedAPIDemoService(
            baseURLString: baseURL,
            certificateResourceName: certificateName
        )
    }

    @MainActor
    private func provisionPins() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await makeService().provisionServerPins()
            statusMessage = """
            /server-pins fetched (system trust) & stored:
            certificatePin: \(response.certificatePin)
            publicKeyPin: \(response.publicKeyPin)
            """
        } catch {
            statusMessage = "Fetch pins failed: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func validateServerPin() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let service = makeService()
            let result = try await service.fetchServerPinAndValidateTrust()
            let verdict = result.matched ? "✅ TRUSTED — pin matches stored /server-pins"
                                         : "❌ NOT TRUSTED — pin not in stored /server-pins"

            // Also ask the backend to validate the pin via POST /api/pinning/validate.
            let serverValidation = try await service.validate(pin: result.pin)

            statusMessage = """
            \(verdict)
            /server-pin: \(result.pin)
            stored pins: \(result.expectedPins.joined(separator: ", "))

            /validate (server): matched=\(serverValidation.matched)
            message: \(serverValidation.message)
            expectedPin: \(serverValidation.expectedPin)
            """
        } catch {
            statusMessage = "Validate /server-pin failed: \(error.localizedDescription)"
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(PinStore.shared)
}
