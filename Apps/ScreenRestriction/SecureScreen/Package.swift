// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SecureScreen",
    platforms: [.iOS("16.0.0")],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SecureScreen",
            targets: ["SecureScreen"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SecureScreen",
            path: "Sources/SecureScreen"),
        .testTarget(
            name: "SecureScreenTests",
            dependencies: ["SecureScreen"],
            path: "Tests/SecureScreenTests"),
    ]
)

