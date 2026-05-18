//
//  ContentView.swift
//  UnitTest
//
//  Created by Ashish Awasthi on 14/05/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var flowViewModel: AuthFlowViewModel
    @StateObject private var signInViewModel: SignInViewModel
    @StateObject private var signUpViewModel: SignUpViewModel

    init(dependencies: AppDependencies = AppDependencies()) {
        let flowViewModel = AuthFlowViewModel(connectivity: dependencies.connectivity)
        let signInViewModel = SignInViewModel(signInUseCase: dependencies.signInUserUseCase)
        let signUpViewModel = SignUpViewModel(registerUserUseCase: dependencies.registerUserUseCase)
        _flowViewModel = StateObject(wrappedValue: flowViewModel)
        _signInViewModel = StateObject(wrappedValue: signInViewModel)
        _signUpViewModel = StateObject(wrappedValue: signUpViewModel)
    }

    var body: some View {
        Group {
            if let user = flowViewModel.authenticatedUser {
                HomeView(user: user, onSignOut: handleSignOut)
            } else {
                screenView
            }
        }
        .animation(.default, value: flowViewModel.authenticatedUser?.id)
        .animation(.default, value: currentScreenKey)
    }

    @ViewBuilder
    private var screenView: some View {
        switch flowViewModel.screen {
        case .choice:
            AuthChoiceView(
                connectivity: flowViewModel.connectivity,
                onSignIn: showSignIn,
                onSignUp: showSignUp
            )
        case .signIn:
            SignInView(
                connectivity: flowViewModel.connectivity,
                viewModel: signInViewModel,
                onAuthenticated: completeAuthentication,
                onCreateAccount: showSignUp,
                onUserNotFound: handleMissingUser
            )
        case .signUp:
            SignUpView(
                connectivity: flowViewModel.connectivity,
                viewModel: signUpViewModel,
                onAuthenticated: completeAuthentication,
                onShowSignIn: showSignIn
            )
        }
    }

    private var currentScreenKey: String {
        switch flowViewModel.screen {
        case .choice:
            return "choice"
        case .signIn:
            return "signIn"
        case .signUp:
            return "signUp"
        }
    }

    private func showSignIn() {
        signInViewModel.errorMessage = nil
        flowViewModel.showSignIn()
    }

    private func showSignUp() {
        signUpViewModel.errorMessage = nil
        flowViewModel.showSignUp()
    }

    private func handleMissingUser(identifier: String) {
        signUpViewModel.prefill(from: identifier)
        flowViewModel.showSignUp()
    }

    private func completeAuthentication(user: User) {
        flowViewModel.completeAuthentication(user: user)
    }

    private func handleSignOut() {
        signInViewModel.reset()
        signUpViewModel.reset()
        flowViewModel.signOut()
    }
}

#Preview {
    ContentView(dependencies: AppDependencies())
}
