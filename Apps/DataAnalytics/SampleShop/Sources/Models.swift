import Foundation
import AnalyticsSDK

// MARK: - Products

struct Product: Identifiable, Hashable {
    let id: String
    let name: String
    let category: String
    let price: Double
    let symbol: String          // SF Symbol shown instead of a photo
    let details: String

    static let catalog: [Product] = [
        Product(id: "p-100", name: "Running Shoes", category: "Shoes", price: 89.99, symbol: "shoe", details: "Light shoes for daily runs."),
        Product(id: "p-101", name: "Trail Boots", category: "Shoes", price: 129.50, symbol: "figure.hiking", details: "Waterproof boots for rough paths."),
        Product(id: "p-200", name: "Rain Jacket", category: "Clothing", price: 74.00, symbol: "cloud.rain", details: "Packable and waterproof."),
        Product(id: "p-201", name: "Wool Sweater", category: "Clothing", price: 59.90, symbol: "tshirt", details: "Warm sweater, 100% wool."),
        Product(id: "p-300", name: "Water Bottle", category: "Gear", price: 19.99, symbol: "waterbottle", details: "Steel bottle, keeps drinks cold for 24 hours."),
        Product(id: "p-301", name: "Backpack 25L", category: "Gear", price: 64.00, symbol: "backpack", details: "Daypack with a laptop sleeve."),
        Product(id: "p-400", name: "Smart Watch", category: "Electronics", price: 199.00, symbol: "applewatch", details: "Tracks steps, sleep and workouts."),
        Product(id: "p-401", name: "Earbuds", category: "Electronics", price: 49.00, symbol: "earbuds", details: "Wireless earbuds with 8 hours of battery."),
    ]

    static let categories = ["All"] + Array(Set(catalog.map(\.category))).sorted()

    /// Product information that goes into every product event.
    var analyticsProperties: [String: AnalyticsValue] {
        ["product_id": .string(id), "product_name": .string(name), "category": .string(category),
         "price": .double(price), "currency": "USD"]
    }
}

struct CartLine: Identifiable {
    let product: Product
    var quantity: Int
    var id: String { product.id }
    var total: Double { product.price * Double(quantity) }
}

// MARK: - Demo users

/// Demo accounts. We send an opaque id and non-identifying traits only. Names and e-mail addresses
/// stay on the device (the SDK also refuses properties that look like e-mail addresses).
struct DemoUser: Identifiable, Hashable {
    let id: String              // opaque user id, this is what the SDK gets
    let displayName: String     // shown in the app only, never sent
    let plan: String
    let country: String
    let ageGroup: String

    static let all: [DemoUser] = [
        DemoUser(id: "user-1001", displayName: "Alice", plan: "premium", country: "US", ageGroup: "25-34"),
        DemoUser(id: "user-1002", displayName: "Bob", plan: "free", country: "IN", ageGroup: "18-24"),
        DemoUser(id: "user-1003", displayName: "Carol", plan: "premium", country: "DE", ageGroup: "35-44"),
    ]

    var traits: [String: AnalyticsValue] {
        ["plan": .string(plan), "country": .string(country), "age_group": .string(ageGroup)]
    }
}

// MARK: - Showing property values in the event log

extension AnalyticsValue {
    var text: String {
        switch self {
        case .string(let s): return s
        case .int(let i): return String(i)
        case .double(let d): return String(format: "%.2f", d)
        case .bool(let b): return b ? "true" : "false"
        }
    }
}
