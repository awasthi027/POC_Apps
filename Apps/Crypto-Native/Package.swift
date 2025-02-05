// swift-tools-version: 5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Crypto-Native",
    platforms: [.iOS("15.0.0"), .macOS("11")],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Crypto-Native",
            targets: ["Crypto-Native"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Crypto-Native"),
        .testTarget(
            name: "Crypto-NativeTests",
            dependencies: ["Crypto-Native"]
        ),
    ]
)
