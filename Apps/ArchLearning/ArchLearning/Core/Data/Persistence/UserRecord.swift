//
//  UserRecord.swift
//  ArchLearning
//
//  SwiftData persistence model. This is the *default* local data source
//  for the app. Kept isolated from UserEntity so the persistence framework
//  (SwiftData today, maybe something else tomorrow) never leaks into the
//  domain or presentation layers.
//

import Foundation
import SwiftData

@Model
final class UserRecord {
    @Attribute(.unique) var id: Int
    var email: String
    var firstName: String
    var lastName: String
    var avatarURLString: String?

    init(id: Int, email: String, firstName: String, lastName: String, avatarURLString: String?) {
        self.id = id
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.avatarURLString = avatarURLString
    }
}

extension UserRecord {
    convenience init(entity: UserEntity) {
        self.init(
            id: entity.id,
            email: entity.email,
            firstName: entity.firstName,
            lastName: entity.lastName,
            avatarURLString: entity.avatarURL?.absoluteString
        )
    }

    func toEntity() -> UserEntity {
        UserEntity(
            id: id,
            email: email,
            firstName: firstName,
            lastName: lastName,
            avatarURL: avatarURLString.flatMap(URL.init(string:))
        )
    }
}
