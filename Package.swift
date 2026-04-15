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
        ),
        .executable(
            name: "SwiftGrabApp",
            targets: ["SwiftGrabApp"]
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
        .executableTarget(
            name: "SwiftGrabApp",
            dependencies: ["SwiftGrab"]
        ),
        .testTarget(
            name: "SwiftGrabTests",
            dependencies: ["SwiftGrab"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
