import SwiftUI

struct ShopView: View {
    @EnvironmentObject private var store: ShopStore
    @EnvironmentObject private var analytics: AppAnalytics
    @State private var query = ""
    @State private var category = "All"

    private var products: [Product] {
        Product.catalog.filter { product in
            (category == "All" || product.category == category)
                && (query.isEmpty || product.name.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Picker("Category", selection: $category) {
                    ForEach(Product.categories, id: \.self) { Text($0) }
                }
                .pickerStyle(.segmented)
                .listRowSeparator(.hidden)

                ForEach(products) { product in
                    NavigationLink(value: product) { ProductRow(product: product) }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Shop")
            .navigationDestination(for: Product.self) { product in
                ProductDetailView(product: product, source: query.isEmpty ? "list" : "search")
            }
            .searchable(text: $query, prompt: "Search products")
            .onChange(of: category) { _, new in store.categorySelected(new) }
            .onSubmit(of: .search) { store.searched(query, results: products.count) }
            .onAppear { analytics.screen("Shop") }
        }
    }
}

struct ProductRow: View {
    let product: Product

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: product.symbol)
                .font(.title2)
                .frame(width: 48, height: 48)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading) {
                Text(product.name).font(.headline)
                Text(product.category).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Text(product.price, format: .currency(code: "USD"))
        }
    }
}

struct ProductDetailView: View {
    let product: Product
    let source: String
    @EnvironmentObject private var store: ShopStore
    @EnvironmentObject private var analytics: AppAnalytics
    @State private var added = false

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: product.symbol)
                .font(.system(size: 70))
                .frame(maxWidth: .infinity, minHeight: 180)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
            Text(product.name).font(.title2.bold())
            Text(product.details).foregroundStyle(.secondary)
            Text(product.price, format: .currency(code: "USD")).font(.title3)
            Button {
                store.add(product)
                added = true
            } label: {
                Label(added ? "Added, add another" : "Add to cart", systemImage: "cart.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Spacer()
        }
        .padding()
        .navigationTitle(product.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            analytics.screen("ProductDetail")
            store.productViewed(product, source: source)
        }
    }
}
