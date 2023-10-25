//
//  LoginView.swift
//  UITestPOC
//
//  Created by Ashish Awasthi on 16/10/23.
//

import SwiftUI

enum LoginOptionType: Int {
    case requestLogin
}
struct LoginView: View {
    @Environment(\.currentRootView) var rootView
    @State var userNameTxt: String = ""
    @State var passwordTxt: String = ""
    @State var isDiableLoginButton: Bool = true

    var body: some View {

        VStack(spacing: 10) {
            TextField("username", text: self.$userNameTxt)
                .accessibilityIdentifier("usernameInputField")
            SecureField("secure password", text: self.$passwordTxt)
                .onChange(of:  self.passwordTxt) {
                    if !self.userNameTxt.isEmpty,
                       !self.passwordTxt.isEmpty {
                        self.isDiableLoginButton = false
                    }
                }
                .accessibilityIdentifier("passwordInputField")
            Button {
                UserDefaults.isUserLogin = true
                self.rootView.wrappedValue = .productList
            } label: {
              Text("Request Login")
            }
            .background(self.isDiableLoginButton ? .black : .yellow)
            .disabled(self.isDiableLoginButton)
            .accessibilityIdentifier("loginRequestButton")

        }
        .navigationTitle("Login")
        .padding()
    }
}

