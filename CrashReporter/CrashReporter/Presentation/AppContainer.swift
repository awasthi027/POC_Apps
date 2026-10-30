import Foundation

@MainActor
enum AppContainer {
    static func makeCrashListViewModel() -> CrashListViewModel {
        let repository = FileCrashRepository()
        return CrashListViewModel(
            fetch: FetchCrashReportsUseCase(repository: repository),
            delete: DeleteCrashReportsUseCase(repository: repository),
            generate: GenerateCrashUseCase(generator: IntentionalCrashGenerator()))
    }
}
