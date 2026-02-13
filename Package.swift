// swift-tools-version:6.2

import PackageDescription

let package = Package(
    name: "SwiftlyFeedbackKitVapor",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "SwiftlyFeedbackKitVapor",
            targets: ["SwiftlyFeedbackKitVapor"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.89.0"),
    ],
    targets: [
        .target(
            name: "SwiftlyFeedbackKitVapor",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
            ]
        ),
        .testTarget(
            name: "SwiftlyFeedbackKitVaporTests",
            dependencies: [
                "SwiftlyFeedbackKitVapor",
                .product(name: "XCTVapor", package: "vapor"),
            ]
        ),
    ]
)
