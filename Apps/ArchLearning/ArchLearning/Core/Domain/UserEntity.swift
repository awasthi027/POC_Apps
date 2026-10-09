//
//  UserEntity.swift
//  ArchLearning
//
//  Domain-layer entity. Plain value type with no knowledge of networking
//  or persistence frameworks, so it can be shared by every data source,
//  repository, use case, and view model regardless of architecture style.
//

import Foundation

struct UserEntity: Identifiable, Equatable, Hashable, Sendable {
    let id: Int
    let email: String
    let firstName: String
    let lastName: String
    let avatarURL: URL?

    var fullName: String {
        "\(firstName) \(lastName)"
    }
}
