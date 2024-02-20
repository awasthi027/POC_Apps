// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "clipoc",
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "0.2.0"),
    ],
    targets: [
        .executableTarget(
            name: "clipoc",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]),
          .testTarget(
            name: "coloricoTests",
            dependencies: ["colorico"], path: "Tests"),
    ]
)
