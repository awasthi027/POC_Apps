//
//  ContentView.swift
//  UITestPOC
//
//  Created by Ashish Awasthi on 16/10/23.
//

import SwiftUI
enum HomeOptionType: Int {
    case login
    case uiLayoutView
}

struct HomeViewScreen: View {
    @State var isNavigate: Bool = false
    @Environment(\.currentRootView) var rootView
    @State var searchText: String = ""

    @State private var isSharePresented: Bool = false
    @State private var showActionSheet = false

    var body: some View {

        VStack {
            Button {

            } label: {
                NavigationLink(value: HomeOptionType.login) {
                    Text("Login Button")
                }
            }
            .accessibilityIdentifier("loginButton")

            Text("User took action")
            .accessibility(identifier: "userActionTextField")

            Button {

            } label: {
                NavigationLink(value: HomeOptionType.uiLayoutView) {
                    Text("UILayout View For Test")
                }
            }
            .accessibilityIdentifier("uiLayoutActionButton")
        }
        .navigationDestination(for: HomeOptionType.self) { item in
            switch item {
            case .login:
                LoginView()
                    .environment(\.currentRootView, self.rootView)
            case .uiLayoutView:
                UILayoutViews()
            }

        }
        .navigationBarTitle("Home", displayMode: .inline)
        .navigationViewStyle(.automatic)

    }
}



