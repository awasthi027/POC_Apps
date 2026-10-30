# AnalyticsSDK (iOS 15+, Swift)

Durable, batched, privacy-conscious analytics client. No third-party dependencies.

```swift
var configuration = AnalyticsConfiguration(projectID: "example-project",
                                           endpoint: URL(string: "https://analytics.example.com/v1/analytics/events")!,
                                           credentials: KeychainCredentialProvider(service: "analytics", account: "token"))
configuration.initialConsent = .granted           // default is .denied (opt-in)

let analytics = AnalyticsSDK(configuration: configuration)
try await analytics.initialize()                  // idempotent

try await analytics.track("product_viewed", properties: ["product_id": "123", "source": "search"])  // returns after COMMIT
analytics.enqueue("scroll_tick")                  // non-blocking, not yet durable
try await analytics.identify(userID: "user-456", properties: ["plan": "premium"])
let report = try await analytics.flush()          // waits; report.status / remainingEvents
try await analytics.setConsent(.denied)           // deletes queued events by default
```

* Design, trade-offs, diagrams, limitations: [docs/DESIGN.md](docs/DESIGN.md)
* Server contract: [docs/BACKEND_CONTRACT.md](docs/BACKEND_CONTRACT.md)
* Cross-question answers: [docs/DEFENSE.md](docs/DEFENSE.md)

Tests: `swift test` (or `./scripts/run-tests.sh` where SwiftPM cannot start its own sandbox).
Delivery is **at-least-once with stable event IDs and an idempotent server — not exactly-once.**
