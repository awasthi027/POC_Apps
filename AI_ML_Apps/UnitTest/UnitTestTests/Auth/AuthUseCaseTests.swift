import XCTest
@testable import UnitTest

@MainActor
final class AuthUseCaseTests: XCTestCase {
    func test_signInUseCase_propagatesUserNotFound() async {
        let repository = makeRepository(remoteUsers: [])
        let useCase = SignInUserUseCase(validator: AuthValidator(), repository: repository)
        let request = SignInRequest(identifier: "unknown", password: "Password123")

        do {
            _ = try await useCase.execute(request: request)
            XCTFail("Expected sign in to fail.")
        } catch {
            XCTAssertEqual(error as? AuthError, .userNotFound)
        }
    }

    func test_registerUseCase_returnsCreatedUser() async throws {
        let repository = makeRepository(remoteUsers: [])
        let useCase = RegisterUserUseCase(validator: AuthValidator(), repository: repository)
        let request = RegistrationRequest(
            firstName: "Jamie",
            lastName: "Stone",
            email: "jamie@example.com",
            username: "jamie",
            password: "Password123",
            confirmPassword: "Password123"
        )

        let user = try await useCase.execute(request: request)

        XCTAssertEqual(user.firstName, "Jamie")
        XCTAssertEqual(user.username, "jamie")
        XCTAssertEqual(user.email, "jamie@example.com")
    }

    private func makeRepository(remoteUsers: [User]) -> DefaultAuthenticationRepository {
        let persistenceController = PersistenceController(inMemory: true)
        let localStore = CoreDataLocalUserStore(persistenceController: persistenceController)
        let remoteStore = MockAuthRemoteDataSource(seedUsers: remoteUsers)
        let connectivity = TestConnectivity(isOnline: true)
        return DefaultAuthenticationRepository(
            remote: remoteStore,
            local: localStore,
            connectivity: connectivity
        )
    }
}

@MainActor
private final class TestConnectivity: ConnectivityProviding {
    let isOnline: Bool

    init(isOnline: Bool) {
        self.isOnline = isOnline
    }
}
