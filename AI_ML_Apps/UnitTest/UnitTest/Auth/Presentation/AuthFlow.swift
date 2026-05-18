import Combine
import Foundation

final class AppConnectivityMonitor: ObservableObject, ConnectivityProviding {
    @Published private(set) var isOnline: Bool

    init(isOnline: Bool = true) {
        self.isOnline = isOnline
    }

    func toggle() {
        isOnline.toggle()
    }
}

enum AuthScreen {
    case choice
    case signIn
    case signUp
}

@MainActor
final class AuthFlowViewModel: ObservableObject {
    @Published private(set) var authenticatedUser: User?
    @Published private(set) var screen: AuthScreen = .choice
    let connectivity: AppConnectivityMonitor

    init(connectivity: AppConnectivityMonitor) {
        self.connectivity = connectivity
    }

    func showChoice() {
        screen = .choice
    }

    func showSignIn() {
        screen = .signIn
    }

    func showSignUp() {
        screen = .signUp
    }

    func completeAuthentication(user: User) {
        authenticatedUser = user
    }

    func signOut() {
        authenticatedUser = nil
        screen = .choice
    }
}

enum SignInOutcome: Equatable {
    case authenticated(User)
    case needsRegistration(String)
}

@MainActor
final class SignInViewModel: ObservableObject {
    @Published var identifier = ""
    @Published var password = ""
    @Published var errorMessage: String?
    @Published private(set) var isLoading = false

    private let signInUseCase: SignInUserUseCase

    init(signInUseCase: SignInUserUseCase) {
        self.signInUseCase = signInUseCase
    }

    func signIn() async -> SignInOutcome? {
        isLoading = true
        defer { isLoading = false }
        do {
            let request = SignInRequest(identifier: identifier, password: password)
            let user = try await signInUseCase.execute(request: request)
            errorMessage = nil
            return .authenticated(user)
        } catch let error as AuthError {
            return handle(error: error)
        } catch {
            errorMessage = AuthError.serverFailure.userMessage
            return nil
        }
    }

    func reset() {
        identifier = ""
        password = ""
        errorMessage = nil
    }

    private func handle(error: AuthError) -> SignInOutcome? {
        switch error {
        case .userNotFound:
            errorMessage = nil
            return .needsRegistration(identifier.trimmingCharacters(in: .whitespacesAndNewlines))
        default:
            errorMessage = error.userMessage
            return nil
        }
    }
}

@MainActor
final class SignUpViewModel: ObservableObject {
    @Published var firstName = ""
    @Published var lastName = ""
    @Published var email = ""
    @Published var username = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var errorMessage: String?
    @Published private(set) var isLoading = false

    private let registerUserUseCase: RegisterUserUseCase

    init(registerUserUseCase: RegisterUserUseCase) {
        self.registerUserUseCase = registerUserUseCase
    }

    func signUp() async -> User? {
        isLoading = true
        defer { isLoading = false }
        do {
            let request = RegistrationRequest(
                firstName: firstName,
                lastName: lastName,
                email: email,
                username: username,
                password: password,
                confirmPassword: confirmPassword
            )
            let user = try await registerUserUseCase.execute(request: request)
            errorMessage = nil
            return user
        } catch let error as AuthError {
            errorMessage = error.userMessage
            return nil
        } catch {
            errorMessage = AuthError.serverFailure.userMessage
            return nil
        }
    }

    func prefill(from identifier: String) {
        let value = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.isEmpty == false else {
            return
        }
        if value.contains("@") {
            email = value
            return
        }
        username = value
    }

    func reset() {
        firstName = ""
        lastName = ""
        email = ""
        username = ""
        password = ""
        confirmPassword = ""
        errorMessage = nil
    }
}
