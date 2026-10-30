import Foundation
import AnalyticsSDK

/// The only place in the app that talks to the SDK.
/// The rest of the app calls `track(...)`, `screen(...)`, `identify(...)`. It never sees SDK details.
/// The SDK uploads by itself: when 20 events are waiting, every 15 seconds, and when the app becomes
/// active or goes to the background.
@MainActor
final class AppAnalytics: ObservableObject {
    @Published private(set) var consentGranted = true

    private let sdk: AnalyticsSDK

    init() {
        // The server address can be changed in Info.plist (key AnalyticsEndpoint), for example to your Mac's IP
        // when you run on a real iPhone. "localhost" works in the iOS Simulator.
        let text = Bundle.main.object(forInfoDictionaryKey: "AnalyticsEndpoint") as? String
        let endpoint = URL(string: text ?? "http://localhost:8080/v1/analytics/events")!

        var config = AnalyticsConfiguration(projectID: "sampleshop", endpoint: endpoint)
        config.initialConsent = .granted        // demo only. A real app asks the user first (default is .denied)
        config.upload.maxBatchEvents = 20
        config.upload.uploadInterval = 15
        sdk = AnalyticsSDK(configuration: config)
    }

    // MARK: - Start

    func start() async {
        do {
            try await sdk.initialize()
            consentGranted = sdk.consentState == .granted
        } catch {
            print("Analytics failed to start: \(error)")
        }
    }

    // MARK: - Recording events

    func screen(_ name: String) {
        Task {
            do { try await sdk.trackScreen(name) } catch { print("Analytics: \(error)") }
        }
    }

    func track(_ name: String, _ properties: [String: AnalyticsValue] = [:]) {
        Task {
            do { try await sdk.track(name, properties: properties) } catch { print("Analytics: \(error)") }
        }
    }

    func identify(_ user: DemoUser) {
        Task {
            do { try await sdk.identify(userID: user.id, properties: user.traits) } catch { print("Analytics: \(error)") }
        }
    }

    /// Logout: the SDK forgets the user and starts a new anonymous identity.
    func reset() {
        Task {
            do { try await sdk.reset() } catch { print("Analytics: \(error)") }
        }
    }

    // MARK: - Consent

    func setConsent(_ granted: Bool) async {
        do {
            try await sdk.setConsent(granted ? .granted : .denied)   // denying also deletes events not yet sent
            consentGranted = granted
        } catch {
            print("Analytics: could not change consent: \(error)")
        }
    }
}
