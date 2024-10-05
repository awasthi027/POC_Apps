// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "UnitTestLearning",
    targets: [
        .target(
            name: "UnitTestLearning",
            dependencies: []),
        .testTarget(
            name: "UnitTestLearningTests",
            dependencies: ["UnitTestLearning"])
    ]
)
