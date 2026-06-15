// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "BrainAI",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "BrainAICore",
            targets: ["BrainAICore"]
        ),
        .library(
            name: "BrainAISettingsUI",
            targets: ["BrainAISettingsUI"]
        ),
        .executable(
            name: "BrainAITray",
            targets: ["BrainAITray"]
        ),
        .executable(
            name: "BrainAISettings",
            targets: ["BrainAISettings"]
        ),
        .executable(
            name: "BrainAIApp",
            targets: ["BrainAIApp"]
        ),
        .executable(
            name: "BrainAIInstaller",
            targets: ["BrainAIInstaller"]
        ),
        .executable(
            name: "BrainAIMCP",
            targets: ["BrainAIMCP"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.2"),
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.6.0"),
    ],
    targets: [
        // MARK: - Core Library
        .target(
            name: "BrainAICore",
            dependencies: [
                "KeychainAccess",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/BrainAICore",
            resources: [
                .process("Resources"),
            ]
        ),

        // MARK: - Tray App (Menu Bar Agent)
        .executableTarget(
            name: "BrainAITray",
            dependencies: ["BrainAICore"],
            path: "Sources/BrainAITray"
        ),

        // MARK: - Settings UI (shared: main app + optional standalone)
        .target(
            name: "BrainAISettingsUI",
            dependencies: ["BrainAICore"],
            path: "Sources/BrainAISettingsUI"
        ),

        // MARK: - Settings launcher (thin → opens BrainAI.app settings)
        .executableTarget(
            name: "BrainAISettings",
            dependencies: ["BrainAICore"],
            path: "Sources/BrainAISettings"
        ),

        // MARK: - Main UI App (SwiftUI)
        .executableTarget(
            name: "BrainAIApp",
            dependencies: ["BrainAICore", "BrainAISettingsUI"],
            path: "Sources/BrainAIApp"
        ),

        // MARK: - Installer / Setup Wizard
        .executableTarget(
            name: "BrainAIInstaller",
            dependencies: ["BrainAICore"],
            path: "Sources/BrainAIInstaller",
            resources: [
                .process("Resources"),
            ]
        ),

        // MARK: - MCP Server (standalone stdio binary for external agents)
        .executableTarget(
            name: "BrainAIMCP",
            dependencies: ["BrainAICore"],
            path: "Sources/BrainAIMCP"
        ),

        // MARK: - Tests
        .testTarget(
            name: "BrainAICoreTests",
            dependencies: ["BrainAICore"],
            path: "Tests/BrainAICoreTests"
        ),
    ]
)
