import Foundation

struct ProtectedEchoUseCase {
    private let repository: AttestationRepository
    private let provider: AttestationProvider
    private let endpointPath = "/protected/echo"

    init(repository: AttestationRepository, provider: AttestationProvider) {
        self.repository = repository
        self.provider = provider
    }

    func execute(payload: String) async throws -> ProtectedEchoResult {
        guard payload.data(using: .utf8) != nil else {
            throw AppError.invalidPayload
        }
        guard (try? JSONSerialization.jsonObject(with: Data(payload.utf8))) is [String: Any] else {
            throw AppError.invalidPayload
        }

        let binding = RequestBinding(
            method: "POST",
            path: endpointPath,
            bodyData: Data(payload.utf8)
        )
        let assertion = try await provider.createAssertion(for: binding)
        let command = ProtectedEchoCommand(payload: payload, assertion: assertion)
        return try await repository.sendProtectedEcho(command: command)
    }
}
