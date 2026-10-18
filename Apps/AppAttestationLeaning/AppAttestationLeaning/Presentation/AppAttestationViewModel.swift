import Combine
import Foundation

@MainActor
final class AppAttestationViewModel: ObservableObject {
    enum Event {
        case registerTapped
        case protectedEchoTapped
        case protectedProfileTapped
    }

    @Published var keyId: String = "-"
    @Published var lastRequest: String = ""
    @Published var lastResponse: String = ""
    @Published var isBusy = false

    private let baseURLStore: BaseURLProviding
    private let registerUseCase: RegisterAttestationUseCase
    private let protectedEchoUseCase: ProtectedEchoUseCase
    private let protectedProfileUseCase: ProtectedProfileUseCase
    private let payload = #"{"sample":"payload"}"#

    init(
        baseURLStore: BaseURLProviding,
        registerUseCase: RegisterAttestationUseCase,
        protectedEchoUseCase: ProtectedEchoUseCase,
        protectedProfileUseCase: ProtectedProfileUseCase
    ) {
        self.baseURLStore = baseURLStore
        self.registerUseCase = registerUseCase
        self.protectedEchoUseCase = protectedEchoUseCase
        self.protectedProfileUseCase = protectedProfileUseCase
    }

    func send(_ event: Event) {
        switch event {
        case .registerTapped:
            Task { await handleRegister() }
        case .protectedEchoTapped:
            Task { await handleProtectedEcho() }
        case .protectedProfileTapped:
            Task { await handleProtectedProfile() }
        }
    }

    private func handleProtectedProfile() async {
        let normalizedURL = normalizedBaseURL(baseURLStore.baseURL)
        lastRequest = """
        {
          "method" : "GET",
          "url" : "\(normalizedURL)/protected/profile"
        }
        """
        await runOperation(onError: { [weak self] message in
            self?.lastResponse = self?.prettyJSONString(from: [
                "error": message
            ]) ?? message
        }) {
            self.baseURLStore.update(baseURL: normalizedURL)
            let response = try await self.protectedProfileUseCase.execute()
            self.lastResponse = self.prettyJSONString(from: [
                "status": response.status,
                "message": response.message,
                "serverTime": response.serverTime
            ])
        }
    }

    private func handleRegister() async {
        let normalizedURL = normalizedBaseURL(baseURLStore.baseURL)
        lastRequest = """
        {
          "method" : "POST",
          "url" : "\(normalizedURL)/attestation/register"
        }
        """
        await runOperation(onError: { [weak self] message in
            self?.lastResponse = self?.prettyJSONString(from: [
                "error": message
            ]) ?? message
        }) {
            self.baseURLStore.update(baseURL: normalizedURL)
            let createdKeyId = try await self.registerUseCase.execute()
            self.keyId = createdKeyId
            self.lastResponse = self.prettyJSONString(from: [
                "result": "registered",
                "keyId": createdKeyId
            ])
        }
    }

    private func handleProtectedEcho() async {
        let normalizedURL = normalizedBaseURL(baseURLStore.baseURL)
        lastRequest = """
        {
          "method" : "POST",
          "url" : "\(normalizedURL)/protected/echo",
          "body" : \(payload)
        }
        """
        await runOperation(onError: { [weak self] message in
            self?.lastResponse = self?.prettyJSONString(from: [
                "error": message
            ]) ?? message
        }) {
            self.baseURLStore.update(baseURL: normalizedURL)
            let response = try await self.protectedEchoUseCase.execute(payload: self.payload)
            self.lastResponse = self.prettyJSONString(from: [
                "status": response.status,
                "message": response.message,
                "method": response.method,
                "path": response.path,
                "body": response.body
            ])
        }
    }

    private func runOperation(
        onError: @escaping (String) -> Void,
        _ operation: @escaping () async throws -> Void
    ) async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await operation()
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            onError(message)
        }
    }

    private func normalizedBaseURL(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func prettyJSONString(from dictionary: [String: String]) -> String {
        guard
            let data = try? JSONSerialization.data(withJSONObject: dictionary, options: [.prettyPrinted]),
            let text = String(data: data, encoding: .utf8)
        else {
            return dictionary.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
        }
        return text
    }
}
