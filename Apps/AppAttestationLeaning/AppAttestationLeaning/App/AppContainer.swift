import Foundation

struct AppContainer {
    let viewModel: AppAttestationViewModel

    static func makeDefault() -> AppContainer {
        let baseURLStore = BaseURLStore()
        let apiClient = URLSessionAttestationAPIClient()
        let repository = AttestationRepositoryImpl(apiClient: apiClient, baseURLProvider: baseURLStore)
        let provider = DeviceCheckAttestationProvider()
        let registerUseCase = RegisterAttestationUseCase(repository: repository, provider: provider)
        let protectedEchoUseCase = ProtectedEchoUseCase(repository: repository, provider: provider)
        let protectedProfileUseCase = ProtectedProfileUseCase(repository: repository, provider: provider)
        let viewModel = AppAttestationViewModel(
            baseURLStore: baseURLStore,
            registerUseCase: registerUseCase,
            protectedEchoUseCase: protectedEchoUseCase,
            protectedProfileUseCase: protectedProfileUseCase
        )
        return AppContainer(viewModel: viewModel)
    }
}
