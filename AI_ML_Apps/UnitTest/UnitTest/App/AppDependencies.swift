import Foundation

struct LaunchConfiguration {
    let useInMemoryStore: Bool
    let startOffline: Bool
    let seedRemoteUser: Bool
    let seedLocalUser: Bool

    nonisolated static func current() -> LaunchConfiguration {
        let environment = ProcessInfo.processInfo.environment
        return LaunchConfiguration(
            useInMemoryStore: environment["UITEST_IN_MEMORY_STORE"] == "1",
            startOffline: environment["UITEST_START_OFFLINE"] == "1",
            seedRemoteUser: environment["UITEST_SEED_REMOTE_USER"] == "1",
            seedLocalUser: environment["UITEST_SEED_LOCAL_USER"] == "1"
        )
    }
}

final class AppDependencies {
    let connectivity: AppConnectivityMonitor
    let registerUserUseCase: RegisterUserUseCase
    let signInUserUseCase: SignInUserUseCase

    init(configuration: LaunchConfiguration = .current()) {
        let validator = AuthValidator()
        let persistenceController = PersistenceController(inMemory: configuration.useInMemoryStore)
        let localStore = CoreDataLocalUserStore(persistenceController: persistenceController)
        let seedUsers = configuration.seedRemoteUser ? [Self.demoUser] : []
        let remoteStore = MockAuthRemoteDataSource(seedUsers: seedUsers)
        let connectivity = AppConnectivityMonitor(isOnline: configuration.startOffline == false)
        if configuration.seedLocalUser {
            try? localStore.preload(users: [Self.demoUser])
        }
        let repository = DefaultAuthenticationRepository(
            remote: remoteStore,
            local: localStore,
            connectivity: connectivity
        )
        self.connectivity = connectivity
        registerUserUseCase = RegisterUserUseCase(validator: validator, repository: repository)
        signInUserUseCase = SignInUserUseCase(validator: validator, repository: repository)
    }

    nonisolated static let demoUser = User(
        id: "demo-user",
        firstName: "Demo",
        lastName: "User",
        email: "demo@example.com",
        username: "demo",
        password: "Password123"
    )
}
