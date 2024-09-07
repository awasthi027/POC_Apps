//
//  UserRepository.swift
//  CleanArch
//
//  Created by Ashish Awasthi on 30/08/24.
//

import Combine

protocol UserRepository {
    func fetchUsers() -> AnyPublisher<[User], Error>
}

class FetchUsersUseCase {

    private let repository: UserRepository

    init(repository: UserRepository) {
        self.repository = repository
    }

    func execute() -> AnyPublisher<[User], Error> {
        return repository.fetchUsers()
    }
}
