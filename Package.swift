// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftGrab",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SwiftGrab",
            targets: ["SwiftGrab"]
        ),
        .executable(
            name: "SwiftGrabDemo",
            targets: ["SwiftGrabDemo"]
        )
    ],
    targets: [
        .target(
            name: "SwiftGrab"
        ),
        .executableTarget(
            name: "SwiftGrabDemo",
            dependencies: ["SwiftGrab"]
        ),
        .testTarget(
            name: "SwiftGrabTests",
            dependencies: ["SwiftGrab"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
