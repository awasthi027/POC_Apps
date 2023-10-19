//
//  ContentView.swift
//  UITestPOC
//
//  Created by Ashish Awasthi on 16/10/23.
//

import SwiftUI
enum HomeOptionType: Int {
    case login
}

struct HomeViewScreen: View {
    @State var isNavigate: Bool = false
    @Environment(\.currentRootView) var rootView

    var body: some View {

        VStack {
            Button {

            } label: {
                NavigationLink(value: HomeOptionType.login) {
                    Text("Login Button")
                }
            }
            .accessibilityIdentifier("loginButton")
        }
        .navigationDestination(for: HomeOptionType.self) { item in
            LoginView()
                .environment(\.currentRootView, self.rootView)
        }
        .navigationBarTitle("Home", displayMode: .inline)
        .navigationViewStyle(.automatic)

    }
}


