// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Read",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "ReadCore", targets: ["ReadCore"]),
        .executable(name: "ReadApp", targets: ["ReadApp"])
    ],
    targets: [
        .target(name: "ReadCore"),
        .executableTarget(
            name: "ReadApp",
            dependencies: ["ReadCore"]
        ),
        .testTarget(
            name: "ReadCoreTests",
            dependencies: ["ReadCore"]
        )
    ]
)
