//
//  SwiftDataManager.swift
//  BGTaskLearning
//
//  Created by Ashish Awasthi on 22/09/26.
//

import SwiftData
import Foundation

/// Centralized manager for SwiftData access across the entire app
/// Provides singleton access to ModelContainer and DataStore
class SwiftDataManager {
    static let shared = SwiftDataManager()
    
    let modelContainer: ModelContainer
    lazy var dataStore: DataStore = {
        DataStore(modelContext: modelContainer.mainContext)
    }()
    
    private init() {
        let schema = Schema([
            FileDownload.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            self.modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
    
    /// Get the main ModelContext for SwiftData operations
    var mainContext: ModelContext {
        modelContainer.mainContext
    }
}
