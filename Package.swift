// swift-tools-version:5.10
import PackageDescription

// Builds the shared core on its own so it can be unit tested with `swift test`.
let package = Package(
    name: "UsageKit",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "UsageKit", path: "Shared"),
        .testTarget(name: "UsageKitTests", dependencies: ["UsageKit"], path: "Tests/UsageKitTests"),
    ]
)
