// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LocusFeed",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "LocusFeedCore", targets: ["LocusFeedCore"]),
    ],
    targets: [
        .systemLibrary(name: "CSQLite", path: "Sources/CSQLite"),
        .target(
            name: "LocusFeedCore",
            dependencies: ["CSQLite"],
            path: "Sources/LocusFeedCore",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .testTarget(name: "LocusFeedCoreTests", dependencies: ["LocusFeedCore"], path: "Tests/LocusFeedCoreTests"),
    ]
)
