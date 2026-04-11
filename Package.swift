// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "BrainAI",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "BrainAICore",
            targets: ["BrainAICore"]
        ),
        .executable(
            name: "BrainAITray",
            targets: ["BrainAITray"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.2"),
    ],
    targets: [
        // MARK: - Core Library
        .target(
            name: "BrainAICore",
            dependencies: [
                "KeychainAccess",
            ],
            path: "Sources/BrainAICore"
        ),

        // MARK: - Tray App (Menu Bar Agent)
        .executableTarget(
            name: "BrainAITray",
            dependencies: ["BrainAICore"],
            path: "Sources/BrainAITray"
        ),

        // MARK: - Tests
        .testTarget(
            name: "BrainAICoreTests",
            dependencies: ["BrainAICore"],
            path: "Tests/BrainAICoreTests"
        ),
    ]
)
