import SwiftUI

struct CartView: View {
    @EnvironmentObject private var store: ShopStore
    @EnvironmentObject private var analytics: AppAnalytics

    var body: some View {
        NavigationStack {
            Group {
                if store.cart.isEmpty {
                    ContentUnavailableView(store.lastOrderID.map { "Thanks! Order \($0) placed" } ?? "Your cart is empty",
                                           systemImage: store.lastOrderID == nil ? "cart" : "checkmark.circle")
                } else {
                    List {
                        ForEach(store.cart) { line in
                            HStack {
                                Image(systemName: line.product.symbol).frame(width: 32)
                                VStack(alignment: .leading) {
                                    Text(line.product.name)
                                    Text("Quantity \(line.quantity)").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(line.total, format: .currency(code: "USD"))
                            }
                            .swipeActions { Button("Remove", role: .destructive) { store.remove(line) } }
                        }
                        Section {
                            HStack {
                                Text("Total").bold()
                                Spacer()
                                Text(store.cartTotal, format: .currency(code: "USD")).bold()
                            }
                            Button("Checkout") { store.checkout() }
                                .buttonStyle(.borderedProminent)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle("Cart")
            .onAppear { analytics.screen("Cart") }
        }
    }
}
