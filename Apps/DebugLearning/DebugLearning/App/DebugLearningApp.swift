//
//  DebugLearningApp.swift
//  DebugLearning
//
//  Created by Ashish Awasthi on 04/10/26.
//

import SwiftUI
import SwiftData

@main
struct DebugLearningApp: App {
    var sharedModelContainer: ModelContainer = {
        LaunchTimeTracker.measure("ModelContainerSetup") {
            let schema = Schema([
                Item.self,
            ])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    init() {
        LaunchTimeTracker.markAppInit()
    }

    var body: some Scene {
        WindowGroup {
            BaseView()
                .onAppear {
                    LaunchTimeTracker.markFirstFrame()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
