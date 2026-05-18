import Foundation

struct User: Identifiable, Equatable, Sendable {
    let id: String
    let firstName: String
    let lastName: String
    let email: String
    let username: String
    let password: String
}

struct RegistrationRequest: Equatable, Sendable {
    let firstName: String
    let lastName: String
    let email: String
    let username: String
    let password: String
    let confirmPassword: String

    var trimmedFirstName: String {
        firstName.trimmed
    }

    var trimmedLastName: String {
        lastName.trimmed
    }

    var trimmedEmail: String {
        email.trimmed.lowercased()
    }

    var trimmedUsername: String {
        username.trimmed.lowercased()
    }
}

struct SignInRequest: Equatable, Sendable {
    let identifier: String
    let password: String

    var trimmedIdentifier: String {
        identifier.trimmed.lowercased()
    }

    var trimmedPassword: String {
        password.trimmed
    }
}

enum AuthError: LocalizedError, Equatable {
    case emptyField(String)
    case invalidEmail
    case passwordMismatch
    case weakPassword(minimumLength: Int)
    case duplicateUsername
    case duplicateEmail
    case userNotFound
    case invalidCredentials
    case noInternetConnection
    case offlineUserUnavailable
    case serverFailure
    case persistenceFailure

    var userMessage: String {
        switch self {
        case .emptyField(let name):
            return "\(name) is required."
        case .invalidEmail:
            return "Please enter a valid email address."
        case .passwordMismatch:
            return "Password and Confirm Password must match."
        case .weakPassword(let minimumLength):
            return "Password must be at least \(minimumLength) characters long."
        case .duplicateUsername:
            return "That username is already in use."
        case .duplicateEmail:
            return "That email is already in use."
        case .userNotFound:
            return "We couldn't find that user. Please sign up."
        case .invalidCredentials:
            return "The credentials you entered are invalid."
        case .noInternetConnection:
            return "No internet connection. Please try again when you're online."
        case .offlineUserUnavailable:
            return "Offline login is only available for previously synced users."
        case .serverFailure:
            return "The server is temporarily unavailable."
        case .persistenceFailure:
            return "We couldn't access local user data."
        }
    }

    var errorDescription: String? {
        userMessage
    }
}

protocol AuthenticationRepository {
    func register(request: RegistrationRequest) async throws -> User
    func signIn(request: SignInRequest) async throws -> User
}

struct AuthValidator {
    let minimumPasswordLength: Int

    init(minimumPasswordLength: Int = 8) {
        self.minimumPasswordLength = minimumPasswordLength
    }

    func validateRegistration(_ request: RegistrationRequest) throws {
        try require(request.trimmedFirstName, named: "First Name")
        try require(request.trimmedLastName, named: "Last Name")
        try require(request.trimmedEmail, named: "Email")
        try require(request.trimmedUsername, named: "Username")
        try require(request.password.trimmed, named: "Password")
        try require(request.confirmPassword.trimmed, named: "Confirm Password")
        try validate(email: request.trimmedEmail)
        try validate(password: request.password)
        try validateMatching(password: request.password, confirmPassword: request.confirmPassword)
    }

    func validateSignIn(_ request: SignInRequest) throws {
        try require(request.trimmedIdentifier, named: "Username or Email")
        try require(request.trimmedPassword, named: "Password")
    }

    private func require(_ value: String, named name: String) throws {
        guard value.isEmpty == false else {
            throw AuthError.emptyField(name)
        }
    }

    private func validate(email: String) throws {
        let pattern = "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$"
        let range = NSRange(email.startIndex..<email.endIndex, in: email)
        let matches = email.range(
            of: pattern,
            options: [.regularExpression, .caseInsensitive]
        )
        guard matches != nil, range.length == email.utf16.count else {
            throw AuthError.invalidEmail
        }
    }

    private func validate(password: String) throws {
        guard password.trimmed.count >= minimumPasswordLength else {
            throw AuthError.weakPassword(minimumLength: minimumPasswordLength)
        }
    }

    private func validateMatching(password: String, confirmPassword: String) throws {
        guard password == confirmPassword else {
            throw AuthError.passwordMismatch
        }
    }
}

struct RegisterUserUseCase {
    private let validator: AuthValidator
    private let repository: AuthenticationRepository

    init(validator: AuthValidator, repository: AuthenticationRepository) {
        self.validator = validator
        self.repository = repository
    }

    func execute(request: RegistrationRequest) async throws -> User {
        try validator.validateRegistration(request)
        return try await repository.register(request: request)
    }
}

struct SignInUserUseCase {
    private let validator: AuthValidator
    private let repository: AuthenticationRepository

    init(validator: AuthValidator, repository: AuthenticationRepository) {
        self.validator = validator
        self.repository = repository
    }

    func execute(request: SignInRequest) async throws -> User {
        try validator.validateSignIn(request)
        return try await repository.signIn(request: request)
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
