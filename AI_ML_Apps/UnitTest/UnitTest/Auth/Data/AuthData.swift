import CoreData
import Foundation

protocol AuthRemoteDataSource {
    func register(request: RegistrationRequest) async throws -> User
    func signIn(request: SignInRequest) async throws -> User
}

protocol UserLocalDataSource {
    func save(user: User) async throws
    func findUser(identifier: String) async throws -> User?
    func preload(users: [User]) throws
}

protocol ConnectivityProviding: AnyObject {
    var isOnline: Bool { get }
}

actor MockAuthRemoteDataSource: AuthRemoteDataSource {
    private var users: [User]

    init(seedUsers: [User] = []) {
        users = seedUsers
    }

    func register(request: RegistrationRequest) async throws -> User {
        try await ensureUnique(email: request.trimmedEmail, username: request.trimmedUsername)
        let user = await User(
            id: UUID().uuidString,
            firstName: request.trimmedFirstName,
            lastName: request.trimmedLastName,
            email: request.trimmedEmail,
            username: request.trimmedUsername,
            password: request.password
        )
        users.append(user)
        return user
    }

    func signIn(request: SignInRequest) async throws -> User {
        guard let user = await findUser(identifier: request.trimmedIdentifier) else {
            throw AuthError.userNotFound
        }
        guard user.password == request.password else {
            throw AuthError.invalidCredentials
        }
        return user
    }

    private func ensureUnique(email: String, username: String) throws {
        if users.contains(where: { $0.username == username }) {
            throw AuthError.duplicateUsername
        }
        if users.contains(where: { $0.email == email }) {
            throw AuthError.duplicateEmail
        }
    }

    private func findUser(identifier: String) -> User? {
        users.first { user in
            user.username == identifier || user.email == identifier
        }
    }
}

final class CoreDataLocalUserStore: UserLocalDataSource {
    private let container: NSPersistentContainer
    private let loadError: Error?

    init(persistenceController: PersistenceController) {
        container = persistenceController.container
        loadError = persistenceController.loadError
    }

    func save(user: User) async throws {
        try ensureStoreReady()
        try await container.viewContext.perform {
            try self.upsert(user: user, in: self.container.viewContext)
            if self.container.viewContext.hasChanges {
                try self.container.viewContext.save()
            }
        }
    }

    func findUser(identifier: String) async throws -> User? {
        try ensureStoreReady()
        return try await container.viewContext.perform {
            let request = StoredUser.fetchRequest()
            request.fetchLimit = 1
            request.predicate = NSPredicate(
                format: "username =[c] %@ OR email =[c] %@",
                identifier,
                identifier
            )
            return try self.container.viewContext.fetch(request).first?.toUser()
        }
    }

    func preload(users: [User]) throws {
        try ensureStoreReady()
        var preloadError: Error?
        container.viewContext.performAndWait {
            do {
                try self.replaceAllUsers(with: users)
            } catch {
                preloadError = error
            }
        }
        if preloadError != nil {
            throw AuthError.persistenceFailure
        }
    }

    private func ensureStoreReady() throws {
        guard loadError == nil else {
            throw AuthError.persistenceFailure
        }
    }

    private func replaceAllUsers(with users: [User]) throws {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "StoredUser")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        try container.viewContext.execute(deleteRequest)
        users.forEach { user in
            _ = self.makeStoredUser(for: user)
        }
        if container.viewContext.hasChanges {
            try container.viewContext.save()
        }
    }

    private func upsert(user: User, in context: NSManagedObjectContext) throws {
        let request = StoredUser.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", user.id)
        let storedUser = try context.fetch(request).first ?? makeStoredUser(for: user, in: context)
        storedUser.update(from: user)
    }

    private func makeStoredUser(for user: User) -> StoredUser {
        makeStoredUser(for: user, in: container.viewContext)
    }

    private func makeStoredUser(for user: User, in context: NSManagedObjectContext) -> StoredUser {
        let storedUser = StoredUser(context: context)
        storedUser.update(from: user)
        return storedUser
    }
}

struct DefaultAuthenticationRepository: AuthenticationRepository {
    private let remote: AuthRemoteDataSource
    private let local: UserLocalDataSource
    private let connectivity: ConnectivityProviding

    init(
        remote: AuthRemoteDataSource,
        local: UserLocalDataSource,
        connectivity: ConnectivityProviding
    ) {
        self.remote = remote
        self.local = local
        self.connectivity = connectivity
    }

    func register(request: RegistrationRequest) async throws -> User {
        guard connectivity.isOnline else {
            throw AuthError.noInternetConnection
        }
        let user = try await remote.register(request: request)
        try await local.save(user: user)
        return user
    }

    func signIn(request: SignInRequest) async throws -> User {
        guard connectivity.isOnline else {
            return try await signInOffline(request: request)
        }
        let user = try await remote.signIn(request: request)
        try await local.save(user: user)
        return user
    }

    private func signInOffline(request: SignInRequest) async throws -> User {
        guard let user = try await local.findUser(identifier: request.trimmedIdentifier) else {
            throw AuthError.offlineUserUnavailable
        }
        guard user.password == request.password else {
            throw AuthError.invalidCredentials
        }
        return user
    }
}
