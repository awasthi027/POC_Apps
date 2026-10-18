import Foundation

protocol AttestationProvider {
    func createRegistrationCommand() async throws -> RegisterKeyCommand
    func createAssertion(for binding: RequestBinding) async throws -> AttestationAssertion
}
