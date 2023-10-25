//
//  SharedScreen.swift
//  UITestPOC
//
//  Created by Ashish Awasthi on 18/10/23.
//

import SwiftUI

enum RootScreen  {
    case homeView
    case productList
}

struct CurrentRootKey: EnvironmentKey {
    static var defaultValue:  Binding<RootScreen> = .constant(.homeView)
}

extension EnvironmentValues {

    var currentRootView:  Binding<RootScreen> {
        get { self[CurrentRootKey.self] }
        set { self[CurrentRootKey.self] = newValue }
    }
}

struct NavHandler<Content>: View where Content: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        if #available(iOS 16, *) {
            NavigationStack(root: content)
        } else {
            NavigationView(content: content)
        }
    }
}
