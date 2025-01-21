// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "InsuranceAPI",
    platforms: [.iOS("16.0.0"), .macOS("12")],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "InsuranceAPI",
            targets: ["InsuranceAPI"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "InsuranceAPI"),
        .testTarget(
            name: "InsuranceAPITests",
            dependencies: ["InsuranceAPI"]
        ),
    ]
)
