// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Flight",
    platforms: [.iOS("16.0.0"), .macOS("12")],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Flight",
            targets: ["Flight"]),
    ],
    dependencies: [.package(path: "../InsuranceAPI"),
                   .package(path: "../FlightAPI")],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Flight",
            dependencies: [.product(name: "InsuranceAPI", package: "InsuranceAPI"),
                           .product(name: "FlightAPI", package: "FlightAPI")]),
        .testTarget(
            name: "FlightTests",
            dependencies: ["Flight"]
        ),
    ]
)
