//
//  ProductListView.swift
//  UITestPOC
//
//  Created by Ashish Awasthi on 17/10/23.
//

import SwiftUI

struct ProductListView: View {

    @StateObject var viewModel = ProductListViewModel()
    @Environment(\.currentRootView) var rootView

    var body: some View {
        VStack {
            List(viewModel.list, id: \.id) { item in
                NavigationLink(value: item) {
                    ContentViewRow(model: item)
                    .accessibility(identifier: "product_item_\(item.id)")
                }
            }
            .listStyle(.plain)
            .padding(.horizontal, 20)
            .accessibility(identifier: "productListView")
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
        .navigationBarTitle("Product List", displayMode: .inline)
        .navigationDestination(for: Product.self) { content in
            ProductDetailsView(content: content)
        }
        .onAppear {
            self.viewModel.productList { isSuccess, error in
                DispatchQueue.main.async {
                    self.viewModel.publishListModel()
                }
            }
        }
    }
}

struct ContentViewRow: View {
    let model: Product
    var body: some View {
        Text(model.title)
            .accessibility(identifier: "CONTENT_ROW_TEXT")
    }
}

