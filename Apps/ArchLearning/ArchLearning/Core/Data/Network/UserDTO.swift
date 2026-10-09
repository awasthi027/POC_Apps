//
//  UserDTO.swift
//  ArchLearning
//
//  Data Transfer Objects matching the JSON shape returned by
//  https://reqres.in/api/users?page=2. Kept separate from the domain
//  entity so API changes never leak into the rest of the app.
//

import Foundation

struct UsersResponseDTO: Decodable {
    let page: Int
    let perPage: Int
    let total: Int
    let totalPages: Int
    let data: [UserDTO]

    enum CodingKeys: String, CodingKey {
        case page
        case perPage = "per_page"
        case total
        case totalPages = "total_pages"
        case data
    }
}

struct UserDTO: Decodable {
    let id: Int
    let email: String
    let firstName: String
    let lastName: String
    let avatar: String

    enum CodingKeys: String, CodingKey {
        case id, email, avatar
        case firstName = "first_name"
        case lastName = "last_name"
    }
}

extension UserDTO {
    /// Maps the networking-shaped DTO into the architecture-agnostic domain entity.
    func toEntity() -> UserEntity {
        UserEntity(
            id: id,
            email: email,
            firstName: firstName,
            lastName: lastName,
            avatarURL: URL(string: avatar)
        )
    }
}
