// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LiveActivityKit",
    platforms: [
        .iOS(.v17),
        // macOS only so the logic and the views compile and `swift test` runs on a Mac. Live Activities are iOS only.
        .macOS(.v14),
    ],
    products: [
        .library(name: "LiveActivityKit", targets: ["LiveActivityKit"]),
    ],
    targets: [
        .target(name: "LiveActivityKit"),
        .testTarget(name: "LiveActivityKitTests", dependencies: ["LiveActivityKit"]),
    ]
)
