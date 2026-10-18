import Foundation

struct ProtectedProfileUseCase {
    private let repository: AttestationRepository
    private let provider: AttestationProvider
    private let endpointPath = "/protected/profile"

    init(repository: AttestationRepository, provider: AttestationProvider) {
        self.repository = repository
        self.provider = provider
    }

    func execute() async throws -> ProtectedProfileResult {
        let binding = RequestBinding(
            method: "GET",
            path: endpointPath,
            bodyData: Data()
        )
        let assertion = try await provider.createAssertion(for: binding)
        return try await repository.fetchProtectedProfile(assertion: assertion)
    }
}
