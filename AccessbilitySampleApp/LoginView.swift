//
//  LoginView.swift
//  AccessbilitySampleApp
//
//  Created by Ashish Awasthi on 18/05/23.
//

import SwiftUI

struct LoginView: View {
    @State var enterUserName: String = ""
    @State var enterPassword: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            BGView()
            VStack {
                self.loginForm()
            }
        }
    }
}

extension LoginView {
    func loginForm() -> some View {
        VStack {
            Image("pizza")
                .accessibilityLabel("Beautiful pizza photos & pizza slice image.")
            VisionLabel(title: "User name")
            TextField("Required", text: self.$enterUserName)
                .textFieldStyle(.roundedBorder)
                .foregroundColor(.blue)
                .padding(.horizontal, 5)
                .accessibilityHint("Double tap to edit")
                .focused(self.$isFocused)
                .disableAutocorrection(true)
                .onAppear {
                    self.isFocused = true
                }

            VisionLabel(title: "Password")
            TextField("Required", text: self.$enterPassword)
                .textFieldStyle(.roundedBorder)
                .foregroundColor(.blue)
                .padding(.horizontal, 5)
                .accessibilityHint("Double tap to edit")
                .disableAutocorrection(true)
            Button {

            } label: {
                VisionLabel(title: "Login", alignment: .center)
            }
        }
        .navigationTitle("Login")
        .padding(.horizontal, 16)
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
