import Foundation

struct AttestationRepositoryImpl: AttestationRepository {
    private let apiClient: AttestationAPIClient
    private let baseURLProvider: BaseURLProviding

    init(apiClient: AttestationAPIClient, baseURLProvider: BaseURLProviding) {
        self.apiClient = apiClient
        self.baseURLProvider = baseURLProvider
    }

    func register(command: RegisterKeyCommand) async throws {
        let request = RegisterKeyRequestDTO(
            keyId: command.keyId,
            challenge: command.challengeBase64Url,
            clientDataHash: command.clientDataHashBase64Url,
            attestationObject: command.attestationObjectBase64Url
        )
        try await apiClient.register(baseURL: baseURLProvider.baseURL, request: request)
    }

    func fetchProtectedProfile(assertion: AttestationAssertion) async throws -> ProtectedProfileResult {
        let response = try await apiClient.protectedProfile(
            baseURL: baseURLProvider.baseURL,
            assertion: assertion
        )
        return ProtectedProfileResult(
            status: response.status,
            message: response.message,
            serverTime: response.serverTime
        )
    }

    func sendProtectedEcho(command: ProtectedEchoCommand) async throws -> ProtectedEchoResult {
        let payloadData = Data(command.payload.utf8)
        _ = try JSONSerialization.jsonObject(with: payloadData)

        let response = try await apiClient.protectedEcho(
            baseURL: baseURLProvider.baseURL,
            payloadData: payloadData,
            assertion: command.assertion
        )
        return ProtectedEchoResult(
            status: response.status,
            message: response.message,
            method: response.method,
            path: response.path,
            body: response.body
        )
    }
}
