//
//  CrashReporterApp.swift
//  CrashReporter
//
//  Created by Ashish Awasthi on 25/10/26.
//

import SwiftUI

@main
struct CrashReporterApp: App {
    init() { CrashHandler.install() }

    var body: some Scene {
        WindowGroup {
            BaseView(viewModel: AppContainer.makeCrashListViewModel())
        }
    }
}
