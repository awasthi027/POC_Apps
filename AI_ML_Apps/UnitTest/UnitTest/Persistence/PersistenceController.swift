import CoreData
import Foundation

final class PersistenceController {
    let container: NSPersistentContainer
    let loadError: Error?

    init(inMemory: Bool = false) {
        let model = Self.makeModel()
        let initialContainer = NSPersistentContainer(name: "AuthModel", managedObjectModel: model)
        let configuredContainer = Self.configure(container: initialContainer, inMemory: inMemory)
        let error = Self.loadStores(for: configuredContainer)
        container = configuredContainer
        loadError = error
        container.viewContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    private static func configure(
        container: NSPersistentContainer,
        inMemory: Bool
    ) -> NSPersistentContainer {
        let description = NSPersistentStoreDescription()
        description.type = NSSQLiteStoreType
        description.shouldInferMappingModelAutomatically = true
        description.shouldMigrateStoreAutomatically = true
        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
        } else {
            description.url = defaultStoreURL()
        }
        container.persistentStoreDescriptions = [description]
        return container
    }

    private static func loadStores(for container: NSPersistentContainer) -> Error? {
        var storeError: Error?
        let semaphore = DispatchSemaphore(value: 0)
        container.loadPersistentStores { _, error in
            storeError = error
            semaphore.signal()
        }
        semaphore.wait()
        return storeError
    }

    private static func defaultStoreURL() -> URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return (directory ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            .appendingPathComponent("AuthModel.sqlite")
    }

    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        let entity = NSEntityDescription()
        entity.name = "StoredUser"
        entity.managedObjectClassName = NSStringFromClass(StoredUser.self)
        entity.properties = [
            attribute(named: "id"),
            attribute(named: "firstName"),
            attribute(named: "lastName"),
            attribute(named: "email"),
            attribute(named: "username"),
            attribute(named: "password"),
            dateAttribute(named: "lastSyncedAt")
        ]
        entity.uniquenessConstraints = [["id"]]
        model.entities = [entity]
        return model
    }

    private static func attribute(named name: String) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = .stringAttributeType
        attribute.isOptional = false
        return attribute
    }

    private static func dateAttribute(named name: String) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = .dateAttributeType
        attribute.isOptional = false
        return attribute
    }
}

@objc(StoredUser)
final class StoredUser: NSManagedObject {
    @NSManaged var id: String
    @NSManaged var firstName: String
    @NSManaged var lastName: String
    @NSManaged var email: String
    @NSManaged var username: String
    @NSManaged var password: String
    @NSManaged var lastSyncedAt: Date
}

extension StoredUser {
    @nonobjc class func fetchRequest() -> NSFetchRequest<StoredUser> {
        NSFetchRequest<StoredUser>(entityName: "StoredUser")
    }

    func update(from user: User) {
        id = user.id
        firstName = user.firstName
        lastName = user.lastName
        email = user.email
        username = user.username
        password = user.password
        lastSyncedAt = Date()
    }

    func toUser() -> User {
        User(
            id: id,
            firstName: firstName,
            lastName: lastName,
            email: email,
            username: username,
            password: password
        )
    }
}
