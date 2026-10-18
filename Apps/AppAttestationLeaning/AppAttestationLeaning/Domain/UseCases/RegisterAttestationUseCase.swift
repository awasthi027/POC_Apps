import Foundation

struct RegisterAttestationUseCase {
    private let repository: AttestationRepository
    private let provider: AttestationProvider

    init(repository: AttestationRepository, provider: AttestationProvider) {
        self.repository = repository
        self.provider = provider
    }

    func execute() async throws -> String {
        let command = try await provider.createRegistrationCommand()
        try await repository.register(command: command)
        return command.keyId
    }
}
