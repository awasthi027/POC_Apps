import Foundation
import AnalyticsSDK

/// The shop's data (cart, signed-in user) and the events each action records.
@MainActor
final class ShopStore: ObservableObject {
    @Published private(set) var cart: [CartLine] = []
    @Published private(set) var user: DemoUser?
    @Published private(set) var lastOrderID: String?

    private let analytics: AppAnalytics

    init(analytics: AppAnalytics) {
        self.analytics = analytics
    }

    var cartCount: Int { cart.reduce(0) { $0 + $1.quantity } }
    var cartTotal: Double { cart.reduce(0) { $0 + $1.total } }

    // MARK: - Browsing

    func productViewed(_ product: Product, source: String) {
        analytics.track("product_viewed", product.analyticsProperties.merging(["source": .string(source)]) { $1 })
    }

    func searched(_ query: String, results: Int) {
        guard !query.isEmpty else { return }
        analytics.track("search_performed", ["query": .string(query), "results_count": .int(results)])
    }

    func categorySelected(_ category: String) {
        analytics.track("category_selected", ["category": .string(category)])
    }

    // MARK: - Cart

    func add(_ product: Product) {
        if let index = cart.firstIndex(where: { $0.product.id == product.id }) {
            cart[index].quantity += 1
        } else {
            cart.append(CartLine(product: product, quantity: 1))
        }
        analytics.track("add_to_cart", product.analyticsProperties.merging([
            "quantity": .int(1), "cart_item_count": .int(cartCount), "cart_value": .double(cartTotal)]) { $1 })
    }

    func remove(_ line: CartLine) {
        cart.removeAll { $0.id == line.id }
        analytics.track("remove_from_cart", line.product.analyticsProperties.merging([
            "quantity": .int(line.quantity), "cart_value": .double(cartTotal)]) { $1 })
    }

    func checkout() {
        guard !cart.isEmpty else { return }
        let orderID = "order-" + UUID().uuidString.prefix(8).lowercased()
        let itemCount = cartCount, value = cartTotal
        let categories = Set(cart.map(\.product.category)).sorted().joined(separator: ",")

        analytics.track("checkout_started", ["item_count": .int(itemCount), "cart_value": .double(value)])
        // Demo: the "payment" always succeeds. Never send card numbers or other payment details.
        analytics.track("purchase_completed", [
            "order_id": .string(orderID), "revenue": .double(value), "currency": "USD",
            "item_count": .int(itemCount), "categories": .string(categories), "payment_method": "demo_card",
        ])
        lastOrderID = orderID
        cart = []
    }

    // MARK: - User

    func login(_ newUser: DemoUser) {
        user = newUser
        analytics.identify(newUser)                       // every event from now on carries this user id
        analytics.track("login", ["method": "demo", "plan": .string(newUser.plan)])
    }

    func logout() {
        analytics.track("logout")
        analytics.reset()                                 // forget the user; new anonymous id
        user = nil
        cart = []
    }
}
