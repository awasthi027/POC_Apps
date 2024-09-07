//
//  CleanArchApp.swift
//  CleanArch
//
//  Created by Ashish Awasthi on 30/08/24.
//

import SwiftUI

@main
struct CleanArch: App {

    var body: some Scene {
        WindowGroup {
            let dataSource = RemoteUserDataSource()
            let repository = UserRepositoryImpl(dataSource: dataSource)
            let fetchUsersUseCase = FetchUsersUseCase(repository: repository)
            let viewModel = UserViewModel(fetchUsersUseCase: fetchUsersUseCase)
            UserListView(viewModel: viewModel)
        }
    }
}
