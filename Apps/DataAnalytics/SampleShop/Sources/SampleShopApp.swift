import SwiftUI

@main
struct SampleShopApp: App {
    @StateObject private var analytics: AppAnalytics
    @StateObject private var store: ShopStore

    init() {
        let analytics = AppAnalytics()
        _analytics = StateObject(wrappedValue: analytics)
        _store = StateObject(wrappedValue: ShopStore(analytics: analytics))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(analytics)
                .environmentObject(store)
                .task {
                    await analytics.start()
                    analytics.track("app_opened")
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: ShopStore

    var body: some View {
        TabView {
            ShopView()
                .tabItem { Label("Shop", systemImage: "bag") }
            CartView()
                .tabItem { Label("Cart", systemImage: "cart") }
                .badge(store.cartCount)
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
    }
}
