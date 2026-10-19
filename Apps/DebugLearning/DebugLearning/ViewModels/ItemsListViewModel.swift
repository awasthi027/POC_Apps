//
//  ItemsListViewModel.swift
//  DebugLearning
//
//  Created by Ashish Awasthi on 06/10/26.
//

import Foundation
import SwiftData
import SwiftUI
import Combine

/// Owns the add/delete business logic for Core Data (SwiftData) entries.
/// The View still supplies `@Query` results (a SwiftUI-only mechanism) and the
/// `ModelContext`, since those must live in the View's environment.
@MainActor
final class ItemsListViewModel: ObservableObject {
    private var modelContext: ModelContext?

    func configure(context: ModelContext) {
        self.modelContext = context
    }

    func addItem() {
        guard let modelContext else { return }
        withAnimation {
            modelContext.insert(Item(timestamp: Date()))
        }
    }

    func deleteItems(_ items: [Item], at offsets: IndexSet) {
        guard let modelContext else { return }
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}
