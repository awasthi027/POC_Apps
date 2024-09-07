//
//  UserViewModel.swift
//  CleanArch
//
//  Created by Ashish Awasthi on 30/08/24.
//


import Combine
import Foundation

class UserViewModel: ObservableObject {

    @Published var users: [User] = []
    private var cancellables = Set<AnyCancellable>()
    private let fetchUsersUseCase: FetchUsersUseCase

    init(fetchUsersUseCase: FetchUsersUseCase) {
        self.fetchUsersUseCase = fetchUsersUseCase
    }

    func fetchUsers() {
        fetchUsersUseCase.execute()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] users in
                self?.users = users
            })
            .store(in: &cancellables)
    }
}
