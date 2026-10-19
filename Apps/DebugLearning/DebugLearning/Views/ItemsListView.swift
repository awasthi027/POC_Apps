//
//  ItemsListView.swift
//  DebugLearning
//
//  Created by Ashish Awasthi on 04/10/26.
//

import SwiftUI
import SwiftData

/// Core Data (SwiftData) backed list: add/delete timestamped items.
/// All business logic lives in ItemsListViewModel; this View only renders state.
struct ItemsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @StateObject private var viewModel = ItemsListViewModel()

    var body: some View {
        List {
            ForEach(items) { item in
                NavigationLink {
                    Text("Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
                } label: {
                    Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                }
            }
            .onDelete { offsets in
                viewModel.deleteItems(items, at: offsets)
            }
        }
        .navigationTitle("Core Data Entries")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
            ToolbarItem {
                Button(action: viewModel.addItem) {
                    Label("Add Item", systemImage: "plus")
                }
            }
        }
        .onAppear {
            viewModel.configure(context: modelContext)
        }
    }
}

#Preview {
    NavigationStack {
        ItemsListView()
            .modelContainer(for: Item.self, inMemory: true)
    }
}
