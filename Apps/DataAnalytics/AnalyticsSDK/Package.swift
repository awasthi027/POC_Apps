// swift-tools-version:5.9
import PackageDescription

// Minimum deployment target: iOS 15 (URLSession async upload, Date.ISO8601FormatStyle, Swift concurrency
// without back-deployment shims). macOS 14 is declared only so the test suite runs under `swift test`.
//
// No third-party dependencies: persistence uses the system SQLite3 library behind the `EventStore` protocol.
let package = Package(
    name: "AnalyticsSDK",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AnalyticsSDK", targets: ["AnalyticsSDK"])
    ],
    targets: [
        .target(name: "AnalyticsSDK", path: "Sources/AnalyticsSDK"),
        .testTarget(name: "AnalyticsSDKTests", dependencies: ["AnalyticsSDK"], path: "Tests/AnalyticsSDKTests")
    ]
)
