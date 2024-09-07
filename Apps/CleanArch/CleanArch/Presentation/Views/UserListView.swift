//
//  UserListView.swift
//  CleanArch
//
//  Created by Ashish Awasthi on 30/08/24.
//

import SwiftUI

struct UserListView: View {

    @ObservedObject var viewModel: UserViewModel

    var body: some View {
        NavigationView {
            List(viewModel.users) { user in
                Text(user.name)
            }
            .navigationTitle("Users")
            .onAppear {
                viewModel.fetchUsers()
            }
        }
    }
}
