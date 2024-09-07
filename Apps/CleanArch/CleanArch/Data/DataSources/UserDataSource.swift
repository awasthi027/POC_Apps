//
//  UserDataSource.swift
//  CleanArch
//
//  Created by Ashish Awasthi on 30/08/24.
//

import Foundation
import Combine

protocol UserDataSource {
    func fetchUsers() -> AnyPublisher<[User], Error>
}

class RemoteUserDataSource: UserDataSource {

    func fetchUsers() -> AnyPublisher<[User], Error> {
        let url = URL(string: "https://api.github.com/users/timmywheels/repos")!
        return URLSession.shared.dataTaskPublisher(for: url)
            .map { $0.data }
            .decode(type: [User].self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
}
