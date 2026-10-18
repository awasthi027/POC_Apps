import Foundation

protocol AttestationRepository {
    func register(command: RegisterKeyCommand) async throws
    func sendProtectedEcho(command: ProtectedEchoCommand) async throws -> ProtectedEchoResult
    func fetchProtectedProfile(assertion: AttestationAssertion) async throws -> ProtectedProfileResult
}
