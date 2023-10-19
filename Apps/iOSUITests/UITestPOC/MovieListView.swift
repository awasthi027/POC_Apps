//
//  MovieListView.swift
//  UITestPOC
//
//  Created by Ashish Awasthi on 17/10/23.
//

import SwiftUI

struct MovieListView: View {
    
    @StateObject var viewModel = MovieListViewModel()
    @Environment(\.currentRootView) var rootView

    var body: some View {
        VStack {
            List(viewModel.list, id: \.id) { item in
                NavigationLink(value: item) {
                    ContentViewRow(model: item)
                    .accessibility(identifier: "movie_item_\(item.id)")
                }
            }
            .listStyle(.plain)
            .padding(.horizontal, 20)
            .accessibility(identifier: "movieListView")
            .onAppear {
                self.viewModel.publishListModel()
            }
            Button {
                UserDefaults.isUserLogin = false
                self.rootView.wrappedValue = .homeView
            } label: {
                Text("Logout")
            }
            .background(.yellow)
            .accessibilityIdentifier("logoutButton")
             Spacer()
        }
        .navigationBarTitle("Movie List", displayMode: .inline)
        .navigationDestination(for: ListModel.self) { content in
            MovieDetailsView(content: content)
        }
    }
    
    func detailsView(content: ListModel) -> some View {
       return MovieDetailsView(content: content)
    }
}

struct ContentViewRow: View {
    let model: ListModel
    var body: some View {
        Text(model.text)
            .accessibility(identifier: "CONTENT_ROW_TEXT")
    }
}

