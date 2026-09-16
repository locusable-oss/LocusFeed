// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LocusFeed",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "LocusFeedCore", targets: ["LocusFeedCore"]),
    ],
    targets: [
        .target(
            name: "LocusFeedCore",
            path: "Sources/LocusFeedCore",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .testTarget(name: "LocusFeedCoreTests", dependencies: ["LocusFeedCore"], path: "Tests/LocusFeedCoreTests"),
    ]
)
