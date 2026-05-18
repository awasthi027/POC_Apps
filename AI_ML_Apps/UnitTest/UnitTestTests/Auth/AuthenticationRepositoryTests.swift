import XCTest
@testable import UnitTest

@MainActor
final class AuthenticationRepositoryTests: XCTestCase {
    func test_register_whenOffline_throwsNoInternetConnection() async {
        let connectivity = TestConnectivity(isOnline: false)
        let repository = makeRepository(connectivity: connectivity)
        let request = RegistrationRequest(
            firstName: "New",
            lastName: "User",
            email: "new@example.com",
            username: "newuser",
            password: "Password123",
            confirmPassword: "Password123"
        )

        do {
            _ = try await repository.register(request: request)
            XCTFail("Expected offline registration to fail.")
        } catch {
            XCTAssertEqual(error as? AuthError, .noInternetConnection)
        }
    }

    func test_register_duplicateUsername_throwsDuplicateUsername() async {
        let repository = makeRepository(remoteUsers: [AppDependencies.demoUser])
        let request = RegistrationRequest(
            firstName: "Other",
            lastName: "User",
            email: "other@example.com",
            username: AppDependencies.demoUser.username,
            password: "Password123",
            confirmPassword: "Password123"
        )

        do {
            _ = try await repository.register(request: request)
            XCTFail("Expected duplicate username to fail.")
        } catch {
            XCTAssertEqual(error as? AuthError, .duplicateUsername)
        }
    }

    func test_signIn_onlineCachesUserForOfflineAuthentication() async throws {
        let connectivity = TestConnectivity(isOnline: true)
        let repository = makeRepository(
            remoteUsers: [AppDependencies.demoUser],
            connectivity: connectivity
        )
        let request = SignInRequest(
            identifier: AppDependencies.demoUser.username,
            password: AppDependencies.demoUser.password
        )

        let onlineUser = try await repository.signIn(request: request)
        connectivity.isOnline = false
        let offlineUser = try await repository.signIn(request: request)

        XCTAssertEqual(onlineUser, AppDependencies.demoUser)
        XCTAssertEqual(offlineUser, AppDependencies.demoUser)
    }

    func test_signIn_offlineWithoutSyncedUser_throwsOfflineUnavailable() async {
        let repository = makeRepository(connectivity: TestConnectivity(isOnline: false))
        let request = SignInRequest(identifier: "missing", password: "Password123")

        do {
            _ = try await repository.signIn(request: request)
            XCTFail("Expected missing offline user to fail.")
        } catch {
            XCTAssertEqual(error as? AuthError, .offlineUserUnavailable)
        }
    }

    func test_signIn_offlineWithWrongPassword_throwsInvalidCredentials() async {
        let connectivity = TestConnectivity(isOnline: true)
        let repository = makeRepository(
            remoteUsers: [AppDependencies.demoUser],
            connectivity: connectivity
        )
        let validRequest = SignInRequest(
            identifier: AppDependencies.demoUser.email,
            password: AppDependencies.demoUser.password
        )

        _ = try? await repository.signIn(request: validRequest)
        connectivity.isOnline = false

        do {
            _ = try await repository.signIn(request: SignInRequest(identifier: AppDependencies.demoUser.email, password: "WrongPass1"))
            XCTFail("Expected wrong offline password to fail.")
        } catch {
            XCTAssertEqual(error as? AuthError, .invalidCredentials)
        }
    }

    private func makeRepository(
        remoteUsers: [User] = [],
        connectivity: TestConnectivity = TestConnectivity(isOnline: true)
    ) -> DefaultAuthenticationRepository {
        let persistenceController = PersistenceController(inMemory: true)
        let localStore = CoreDataLocalUserStore(persistenceController: persistenceController)
        let remoteStore = MockAuthRemoteDataSource(seedUsers: remoteUsers)
        return DefaultAuthenticationRepository(
            remote: remoteStore,
            local: localStore,
            connectivity: connectivity
        )
    }
}

@MainActor
private final class TestConnectivity: ConnectivityProviding {
    var isOnline: Bool

    init(isOnline: Bool) {
        self.isOnline = isOnline
    }
}
