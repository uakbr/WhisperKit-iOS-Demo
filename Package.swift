// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WhisperKit-iOS-Demo",
    platforms: [.iOS(.v17)],
    products: [
        .library(
            name: "WhisperKit-iOS-Demo",
            targets: ["WhisperKit-iOS-Demo"]),
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", .upToNextMajor(from: "0.2.0")),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.3"),
    ],
    targets: [
        .target(
            name: "WhisperKit-iOS-Demo",
            dependencies: [
                "WhisperKit",
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "WhisperKitDemo"
        ),
        .testTarget(
            name: "WhisperKit-iOS-DemoTests",
            dependencies: ["WhisperKit-iOS-Demo"],
            path: "WhisperKitDemoTests"
        ),
    ]
)
