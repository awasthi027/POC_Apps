// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BLEDevice",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "BLEDevice",
            targets: ["BLEDevice"]
        )
    ],
    targets: [
        .target(
            name: "BLEDevice",
            path: "BLEDevice/Sources"
        ),
        .testTarget(
            name: "BLEDeviceTests",
            dependencies: ["BLEDevice"],
            path: "Tests/BLEDeviceTests"
        )
    ]
)
