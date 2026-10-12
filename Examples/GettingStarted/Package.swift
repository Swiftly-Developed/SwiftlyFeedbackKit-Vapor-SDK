// swift-tools-version:6.2
import PackageDescription

// Compiled by `swift build` in this directory. `../..` is the
// SwiftlyFeedbackKit-Vapor package that contains this example.
// A host app that sits next to a checkout of the package uses
// `.package(path: "../SwiftlyFeedbackKit-Vapor")` instead. The product
// name stays `SwiftlyFeedbackKitVapor`. The `package:` argument is the
// path's directory name for a path dependency, and
// `SwiftlyFeedbackKit-Vapor-SDK` for the git URL.
let package = Package(
    name: "GettingStarted",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(path: "../.."),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.89.0"),
    ],
    targets: [
        .executableTarget(
            name: "GettingStarted",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "SwiftlyFeedbackKitVapor", package: "SwiftlyFeedbackKit-Vapor"),
            ]
        ),
    ]
)
