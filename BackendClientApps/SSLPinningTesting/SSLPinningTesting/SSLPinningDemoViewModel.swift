import Combine
import Foundation

@MainActor
final class SSLPinningDemoViewModel: ObservableObject {
    static let expectedFailurePin = "sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

   // @Published var baseURL = "https://localhost:8443"
    @Published var baseURL = "https://ssl-pinning-service-production.up.railway.app"
    @Published var isRunning = false
    @Published var statusMessage = "Ready to validate the pinned HTTPS API."
    @Published var results: [ValidationResult] = []

    func runValidationSuite() {
        Task {
            await executeSuite()
        }
    }

    func runSecurePing() {
        Task {
            await executeSingle(
                title: "Pinned GET /api/secure/ping",
                expectedSuccess: true
            ) { client in
                let response = try await client.securePing()
                return ValidationResult(
                    title: "Pinned GET /api/secure/ping",
                    outcome: .success,
                    summary: response.secure ? "Pinned TLS request succeeded." : "The endpoint returned secure=false.",
                    detail: response.prettyPrintedJSON()
                )
            }
        }
    }

    func runVerifyWithCorrectPin() {
        Task {
            await executeSingle(
                title: "POST /api/client/verify",
                expectedSuccess: true
            ) { client in
                let response = try await client.verify()
                let outcome: ValidationOutcome = response.pinningPassed ? .success : .failure
                let summary = response.pinningPassed
                    ? "Backend accepted the correct public-key pin."
                    : "Backend did not accept the correct pin."

                return ValidationResult(
                    title: "POST /api/client/verify",
                    outcome: outcome,
                    summary: summary,
                    detail: response.prettyPrintedJSON()
                )
            }
        }
    }

    func runVerifyWithWrongPin() {
        Task {
            await executeSingle(
                title: "POST /api/client/verify?pin=<wrong>",
                expectedSuccess: true
            ) { client in
                let response = try await client.verify(pin: Self.expectedFailurePin)
                let outcome: ValidationOutcome = response.pinningPassed ? .failure : .success
                let summary = response.pinningPassed
                    ? "Backend unexpectedly accepted the wrong pin."
                    : "Backend correctly rejected the wrong pin."

                return ValidationResult(
                    title: "POST /api/client/verify?pin=<wrong>",
                    outcome: outcome,
                    summary: summary,
                    detail: response.prettyPrintedJSON()
                )
            }
        }
    }

    func clearResults() {
        results.removeAll()
        statusMessage = "Results cleared."
    }

    private func executeSuite() async {
        guard !isRunning else { return }

        isRunning = true
        results.removeAll()
        statusMessage = "Running the validation suite..."

        do {
            let client = try SSLPinnedAPIClient(baseURLString: baseURL)

            let pingResponse = try await client.securePing()
            appendResult(
                title: "Pinned GET /api/secure/ping",
                outcome: pingResponse.secure ? .success : .failure,
                summary: pingResponse.secure
                    ? "Pinned TLS request succeeded."
                    : "The endpoint returned secure=false.",
                detail: pingResponse.prettyPrintedJSON()
            )

            let verifyResponse = try await client.verify()
            appendResult(
                title: "POST /api/client/verify",
                outcome: verifyResponse.pinningPassed ? .success : .failure,
                summary: verifyResponse.pinningPassed
                    ? "Backend accepted the correct public-key pin."
                    : "Backend did not accept the correct pin.",
                detail: verifyResponse.prettyPrintedJSON()
            )

            let wrongPinResponse = try await client.verify(pin: Self.expectedFailurePin)
            appendResult(
                title: "POST /api/client/verify?pin=<wrong>",
                outcome: wrongPinResponse.pinningPassed ? .failure : .success,
                summary: wrongPinResponse.pinningPassed
                    ? "Backend unexpectedly accepted the wrong pin."
                    : "Backend correctly rejected the wrong pin.",
                detail: wrongPinResponse.prettyPrintedJSON()
            )

            statusMessage = results.contains(where: { $0.outcome == .failure })
                ? "Suite finished with at least one failed validation."
                : "Suite finished successfully."
        } catch {
            appendResult(
                title: "Validation suite",
                outcome: .failure,
                summary: error.localizedDescription,
                detail: String(describing: error)
            )
            statusMessage = "Suite failed before all checks could finish."
        }

        isRunning = false
    }

    private func executeSingle(
        title: String,
        expectedSuccess: Bool,
        operation: @escaping (SSLPinnedAPIClient) async throws -> ValidationResult
    ) async {
        guard !isRunning else { return }

        isRunning = true
        statusMessage = "Running \(title)..."

        defer {
            isRunning = false
        }

        do {
            let client = try SSLPinnedAPIClient(baseURLString: baseURL)
            let result = try await operation(client)
            results.insert(result, at: 0)
            statusMessage = expectedSuccess && result.outcome == .failure
                ? "\(title) failed."
                : "\(title) completed."
        } catch {
            results.insert(
                ValidationResult(
                    title: title,
                    outcome: .failure,
                    summary: error.localizedDescription,
                    detail: String(describing: error)
                ),
                at: 0
            )
            statusMessage = "\(title) failed."
        }
    }

    private func appendResult(title: String, outcome: ValidationOutcome, summary: String, detail: String) {
        results.append(
            ValidationResult(
                title: title,
                outcome: outcome,
                summary: summary,
                detail: detail
            )
        )
    }
}

struct ValidationResult: Identifiable {
    let id = UUID()
    let title: String
    let outcome: ValidationOutcome
    let summary: String
    let detail: String
    let createdAt = Date()
}

enum ValidationOutcome {
    case success
    case failure

    var label: String {
        switch self {
        case .success:
            return "PASS"
        case .failure:
            return "FAIL"
        }
    }
}

