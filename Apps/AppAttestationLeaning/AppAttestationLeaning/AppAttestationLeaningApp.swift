//
//  AppAttestationLeaningApp.swift
//  AppAttestationLeaning
//
//  Created by Ashish Awasthi on 17/10/26.
//

import SwiftUI

@main
struct AppAttestationLeaningApp: App {
    @StateObject private var viewModel = AppContainer.makeDefault().viewModel

    var body: some Scene {
        WindowGroup {
            BaseView(viewModel: viewModel)
        }
    }
}
