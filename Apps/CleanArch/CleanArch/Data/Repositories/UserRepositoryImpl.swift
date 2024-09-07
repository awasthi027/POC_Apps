//
//  UserRepositoryImpl.swift
//  CleanArch
//
//  Created by Ashish Awasthi on 30/08/24.
//

import Combine

class UserRepositoryImpl: UserRepository {
    
    private let dataSource: UserDataSource

    init(dataSource: UserDataSource) {
        self.dataSource = dataSource
    }

    func fetchUsers() -> AnyPublisher<[User], Error> {
        return dataSource.fetchUsers()
    }
}
