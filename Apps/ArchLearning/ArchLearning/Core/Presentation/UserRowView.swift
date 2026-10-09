//
//  UserRowView.swift
//  ArchLearning
//
//  Shared row UI reused by every demo screen (Clean+MVVM, MVVM-only,
//  MVP-only, Clean+MVP) so the architecture differences stay isolated to
//  the ViewModel/Presenter layer rather than being duplicated per screen.
//

import SwiftUI

struct UserRowView: View {
    let user: UserEntity

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: user.avatarURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(.secondary.opacity(0.2))
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())

            VStack(alignment: .leading) {
                Text(user.fullName).font(.headline)
                Text(user.email).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
