//
//  ContentView.swift
//  UITestPOC
//
//  Created by Ashish Awasthi on 23/07/25.
//

import SwiftUI
import LearningSubspecSDK

struct LoginView: View {
    @Environment(\.currentRootView) var rootView
    @State private var username: String = ""
    @State private var password: String = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Login")
                .font(.largeTitle)
                .bold()
            TextField("Username", text: $username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .accessibilityIdentifier("username.text.field")
            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .accessibilityIdentifier("password.text.field")
            Button(action: {
                LearningSDKManager.shared.loginUser(userName: username, password: password)
                self.rootView.wrappedValue = .homeView
            }) {
                Text("Login")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("login.button")
        }
        .navigationBarTitle("Login", displayMode: .inline)
        .padding()
    }
}

#Preview {
    LoginView()
}

