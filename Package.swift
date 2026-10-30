// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DuoReady",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "duoready", targets: ["DuoReadyCLI"]),
        .library(name: "DuoReadyCore", targets: ["DuoReadyCore"]),
        .library(name: "DuoReadyRules", targets: ["DuoReadyRules"]),
        .library(name: "DuoReadyReporters", targets: ["DuoReadyReporters"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "601.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
    ],
    targets: [
        .target(
            name: "DuoReadyCore",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "DuoReadyRules",
            dependencies: [
                "DuoReadyCore",
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "DuoReadyReporters",
            dependencies: ["DuoReadyCore"]
        ),
        .executableTarget(
            name: "DuoReadyCLI",
            dependencies: [
                "DuoReadyCore",
                "DuoReadyRules",
                "DuoReadyReporters",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "DuoReadyCoreTests",
            dependencies: ["DuoReadyCore"]
        ),
        .testTarget(
            name: "DuoReadyRulesTests",
            dependencies: ["DuoReadyCore", "DuoReadyRules"]
        ),
        .testTarget(
            name: "DuoReadyReporterTests",
            dependencies: ["DuoReadyCore", "DuoReadyReporters"]
        ),
        .testTarget(
            name: "DuoReadyIntegrationTests",
            dependencies: ["DuoReadyCore", "DuoReadyRules"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
