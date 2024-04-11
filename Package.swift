// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "Merge",
    platforms: [
        .iOS(.v13),
        .macOS(.v11),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "Merge",
            targets: ["Merge"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-async-algorithms", exact: Version("1.0.0-alpha")),
        .package(url: "https://github.com/vmanot/Swallow", branch: "master"),
        .package(url: "https://github.com/SwiftUIX/SwiftUIX.git", exact: Version("0.1.5"))
    ],
    targets: [
        .target(
            name: "Merge",
            dependencies: [
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                "Swallow",
                "SwiftUIX"
            ],
            path: "Sources",
            swiftSettings: []
        ),
        .testTarget(
            name: "MergeTests",
            dependencies: [
                "Merge"
            ],
            path: "Tests"
        )
    ]
)
