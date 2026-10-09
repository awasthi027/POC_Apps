//
//  UserDTOTests.swift
//  ArchLearningTests
//
//  Verifies JSON decoding of the reqres.in response shape and the
//  DTO -> domain entity mapping.
//

import Testing
import Foundation
@testable import ArchLearning

struct UserDTOTests {
    @Test func decodesReqResUsersResponse() throws {
        let json = """
        {
            "page": 2,
            "per_page": 6,
            "total": 12,
            "total_pages": 2,
            "data": [
                {
                    "id": 7,
                    "email": "michael.lawson@reqres.in",
                    "first_name": "Michael",
                    "last_name": "Lawson",
                    "avatar": "https://reqres.in/img/faces/7-image.jpg"
                }
            ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(UsersResponseDTO.self, from: json)

        #expect(response.page == 2)
        #expect(response.totalPages == 2)
        #expect(response.data.count == 1)
        #expect(response.data[0].id == 7)
        #expect(response.data[0].firstName == "Michael")
    }

    @Test func mapsDTOToEntity() {
        let dto = UserDTO(
            id: 7,
            email: "michael.lawson@reqres.in",
            firstName: "Michael",
            lastName: "Lawson",
            avatar: "https://reqres.in/img/faces/7-image.jpg"
        )

        let entity = dto.toEntity()

        #expect(entity.id == 7)
        #expect(entity.fullName == "Michael Lawson")
        #expect(entity.avatarURL?.absoluteString == "https://reqres.in/img/faces/7-image.jpg")
    }
}
