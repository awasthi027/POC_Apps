//
//  UnitTestApp.swift
//  UnitTest
//
//  Created by Ashish Awasthi on 14/05/26.
//

import SwiftUI

@main
struct UnitTestApp: App {
    private let dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            ContentView(dependencies: dependencies)
        }
    }
}
