// swift-tools-version: 6.2

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "InnoRouter",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .tvOS(.v18),
        .watchOS(.v11),
        .visionOS(.v2)
    ],
    products: [
        // MARK: - Umbrella
        .library(
            name: "InnoRouter",
            targets: ["InnoRouter"]
        ),

        // MARK: - Core Runtime
        .library(
            name: "InnoRouterCore",
            targets: ["InnoRouterCore"]
        ),
        
        // MARK: - SwiftUI Integration
        .library(
            name: "InnoRouterSwiftUI",
            targets: ["InnoRouterSwiftUI"]
        ),
        
        // MARK: - DeepLink
        .library(
            name: "InnoRouterDeepLink",
            targets: ["InnoRouterDeepLink"]
        ),
        
        // MARK: - InnoFlow Adapter
        .library(
            name: "InnoRouterNavigationEffects",
            targets: ["InnoRouterNavigationEffects"]
        ),
        .library(
            name: "InnoRouterDeepLinkEffects",
            targets: ["InnoRouterDeepLinkEffects"]
        ),
        .library(
            name: "InnoRouterEffects",
            targets: ["InnoRouterEffects"]
        ),
        
        // MARK: - Macros
        .library(
            name: "InnoRouterMacros",
            targets: ["InnoRouterMacros"]
        ),

        // MARK: - Test Harness
        .library(
            name: "InnoRouterTesting",
            targets: ["InnoRouterTesting"]
        ),
    ],
    dependencies: [
        // Swift Syntax for Macros
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "602.0.0"),
    ],
    targets: [
        // MARK: - Core Runtime Target
        .target(
            name: "InnoRouterCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        
        // MARK: - DeepLink Target
        .target(
            name: "InnoRouterDeepLink",
            dependencies: ["InnoRouterCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        
        // MARK: - SwiftUI Target
        .target(
            name: "InnoRouterSwiftUI",
            dependencies: ["InnoRouterCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        
        // MARK: - Umbrella Target
        .target(
            name: "InnoRouter",
            dependencies: ["InnoRouterCore", "InnoRouterSwiftUI", "InnoRouterDeepLink"],
            path: "Sources/InnoRouterUmbrella",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        
        // MARK: - Effects Target
        .target(
            name: "InnoRouterNavigationEffects",
            dependencies: [
                "InnoRouterCore",
            ],
            path: "Sources/InnoRouterNavigationEffects",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "InnoRouterDeepLinkEffects",
            dependencies: [
                "InnoRouterCore",
                "InnoRouterDeepLink",
                "InnoRouterNavigationEffects",
            ],
            path: "Sources/InnoRouterDeepLinkEffects",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "InnoRouterEffects",
            dependencies: [
                "InnoRouterNavigationEffects",
                "InnoRouterDeepLinkEffects",
            ],
            path: "Sources/InnoRouterEffects",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: - Executable Target
        .executableTarget(
            name: "NavigationEnvironmentFailFastProbe",
            dependencies: ["InnoRouterCore", "InnoRouterSwiftUI"],
            path: "Sources/NavigationEnvironmentFailFastProbe",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "ChildCoordinatorFailFastProbe",
            dependencies: ["InnoRouterCore", "InnoRouterSwiftUI"],
            path: "Sources/ChildCoordinatorFailFastProbe",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "InnoRouterPerformanceSmoke",
            dependencies: ["InnoRouter", "InnoRouterDeepLinkEffects"],
            path: "Sources/InnoRouterPerformanceSmoke",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: - Example Build Gates (human-facing Examples/*.swift)
        //
        // Per-file targets so that every example — the same source the README points
        // at — participates in `swift build`. Without this, macro-generated code in
        // `Examples/` is never exercised by a consumer site, so latent generator bugs
        // stay invisible until end-users hit them. The per-file split mirrors
        // `ExamplesSmoke/` because several examples reuse names like `HomeRoute`.
        .target(
            name: "InnoRouterStandaloneExample",
            dependencies: ["InnoRouter", "InnoRouterMacros"],
            path: "Examples",
            exclude: ["CoordinatorExample.swift", "DeepLinkExample.swift", "SplitCoordinatorExample.swift", "AppShellExample.swift", "MultiPlatformExample.swift", "VisionOSImmersiveExample.swift"],
            sources: ["StandaloneExample.swift"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "InnoRouterCoordinatorExample",
            dependencies: ["InnoRouter", "InnoRouterMacros"],
            path: "Examples",
            exclude: ["StandaloneExample.swift", "DeepLinkExample.swift", "SplitCoordinatorExample.swift", "AppShellExample.swift", "MultiPlatformExample.swift", "VisionOSImmersiveExample.swift"],
            sources: ["CoordinatorExample.swift"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "InnoRouterDeepLinkExample",
            dependencies: ["InnoRouter", "InnoRouterMacros"],
            path: "Examples",
            exclude: ["StandaloneExample.swift", "CoordinatorExample.swift", "SplitCoordinatorExample.swift", "AppShellExample.swift", "MultiPlatformExample.swift", "VisionOSImmersiveExample.swift"],
            sources: ["DeepLinkExample.swift"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "InnoRouterSplitCoordinatorExample",
            dependencies: ["InnoRouter", "InnoRouterMacros"],
            path: "Examples",
            exclude: ["StandaloneExample.swift", "CoordinatorExample.swift", "DeepLinkExample.swift", "AppShellExample.swift", "MultiPlatformExample.swift", "VisionOSImmersiveExample.swift"],
            sources: ["SplitCoordinatorExample.swift"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "InnoRouterAppShellExample",
            dependencies: ["InnoRouter", "InnoRouterMacros"],
            path: "Examples",
            exclude: ["StandaloneExample.swift", "CoordinatorExample.swift", "DeepLinkExample.swift", "SplitCoordinatorExample.swift", "MultiPlatformExample.swift", "VisionOSImmersiveExample.swift"],
            sources: ["AppShellExample.swift"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "InnoRouterMultiPlatformExample",
            dependencies: ["InnoRouter", "InnoRouterMacros"],
            path: "Examples",
            exclude: ["StandaloneExample.swift", "CoordinatorExample.swift", "DeepLinkExample.swift", "SplitCoordinatorExample.swift", "AppShellExample.swift", "VisionOSImmersiveExample.swift"],
            sources: ["MultiPlatformExample.swift"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "InnoRouterVisionOSImmersiveExample",
            dependencies: ["InnoRouter", "InnoRouterMacros"],
            path: "Examples",
            exclude: ["StandaloneExample.swift", "CoordinatorExample.swift", "DeepLinkExample.swift", "SplitCoordinatorExample.swift", "AppShellExample.swift", "MultiPlatformExample.swift"],
            sources: ["VisionOSImmersiveExample.swift"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: - Example Smoke Targets
        .target(
            name: "InnoRouterStandaloneExampleSmoke",
            dependencies: ["InnoRouter"],
            path: "ExamplesSmoke",
            exclude: ["CoordinatorSmoke.swift", "DeepLinkSmoke.swift", "SplitCoordinatorSmoke.swift", "AppShellSmoke.swift", "ModalSmoke.swift", "MacrosSmoke.swift", "MultiPlatformSmoke.swift", "VisionOSImmersiveSmoke.swift"],
            sources: ["StandaloneSmoke.swift"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "InnoRouterCoordinatorExampleSmoke",
            dependencies: ["InnoRouter"],
            path: "ExamplesSmoke",
            exclude: ["StandaloneSmoke.swift", "DeepLinkSmoke.swift", "SplitCoordinatorSmoke.swift", "AppShellSmoke.swift", "ModalSmoke.swift", "MacrosSmoke.swift", "MultiPlatformSmoke.swift", "VisionOSImmersiveSmoke.swift"],
            sources: ["CoordinatorSmoke.swift"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "InnoRouterDeepLinkExampleSmoke",
            dependencies: ["InnoRouter"],
            path: "ExamplesSmoke",
            exclude: ["StandaloneSmoke.swift", "CoordinatorSmoke.swift", "SplitCoordinatorSmoke.swift", "AppShellSmoke.swift", "ModalSmoke.swift", "MacrosSmoke.swift", "MultiPlatformSmoke.swift", "VisionOSImmersiveSmoke.swift"],
            sources: ["DeepLinkSmoke.swift"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "InnoRouterSplitCoordinatorExampleSmoke",
            dependencies: ["InnoRouter"],
            path: "ExamplesSmoke",
            exclude: ["StandaloneSmoke.swift", "CoordinatorSmoke.swift", "DeepLinkSmoke.swift", "AppShellSmoke.swift", "ModalSmoke.swift", "MacrosSmoke.swift", "MultiPlatformSmoke.swift", "VisionOSImmersiveSmoke.swift"],
            sources: ["SplitCoordinatorSmoke.swift"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "InnoRouterAppShellExampleSmoke",
            dependencies: ["InnoRouter"],
            path: "ExamplesSmoke",
            exclude: ["StandaloneSmoke.swift", "CoordinatorSmoke.swift", "DeepLinkSmoke.swift", "SplitCoordinatorSmoke.swift", "ModalSmoke.swift", "MacrosSmoke.swift", "MultiPlatformSmoke.swift", "VisionOSImmersiveSmoke.swift"],
            sources: ["AppShellSmoke.swift"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "InnoRouterModalExampleSmoke",
            dependencies: ["InnoRouter"],
            path: "ExamplesSmoke",
            exclude: ["StandaloneSmoke.swift", "CoordinatorSmoke.swift", "DeepLinkSmoke.swift", "SplitCoordinatorSmoke.swift", "AppShellSmoke.swift", "MacrosSmoke.swift", "MultiPlatformSmoke.swift", "VisionOSImmersiveSmoke.swift"],
            sources: ["ModalSmoke.swift"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "InnoRouterMacrosExampleSmoke",
            dependencies: ["InnoRouter", "InnoRouterMacros"],
            path: "ExamplesSmoke",
            exclude: ["StandaloneSmoke.swift", "CoordinatorSmoke.swift", "DeepLinkSmoke.swift", "SplitCoordinatorSmoke.swift", "AppShellSmoke.swift", "ModalSmoke.swift", "MultiPlatformSmoke.swift", "VisionOSImmersiveSmoke.swift"],
            sources: ["MacrosSmoke.swift"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "InnoRouterMultiPlatformExampleSmoke",
            dependencies: ["InnoRouter"],
            path: "ExamplesSmoke",
            exclude: ["StandaloneSmoke.swift", "CoordinatorSmoke.swift", "DeepLinkSmoke.swift", "SplitCoordinatorSmoke.swift", "AppShellSmoke.swift", "ModalSmoke.swift", "MacrosSmoke.swift", "VisionOSImmersiveSmoke.swift"],
            sources: ["MultiPlatformSmoke.swift"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "InnoRouterVisionOSImmersiveExampleSmoke",
            dependencies: ["InnoRouter"],
            path: "ExamplesSmoke",
            exclude: ["StandaloneSmoke.swift", "CoordinatorSmoke.swift", "DeepLinkSmoke.swift", "SplitCoordinatorSmoke.swift", "AppShellSmoke.swift", "ModalSmoke.swift", "MacrosSmoke.swift", "MultiPlatformSmoke.swift"],
            sources: ["VisionOSImmersiveSmoke.swift"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: - Macro Declarations (Public API)
        .target(
            name: "InnoRouterMacros",
            dependencies: ["InnoRouterCore", "InnoRouterMacrosPlugin"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        
        // MARK: - Test Harness Target
        //
        // Ships `NavigationTestStore`, `ModalTestStore`, and `FlowTestStore` so
        // consumers can assert navigation/modal/flow events host-lessly without
        // `@testable import`. Swift-Testing native (`Issue.record`).
        .target(
            name: "InnoRouterTesting",
            dependencies: ["InnoRouterCore", "InnoRouterSwiftUI"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: - Macro Implementation (Compiler Plugin)
        .macro(
            name: "InnoRouterMacrosPlugin",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        
        // MARK: - Tests
        .testTarget(
            name: "InnoRouterTests",
            dependencies: ["InnoRouter", "InnoRouterEffects", "InnoRouterSwiftUI"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "InnoRouterMacrosTests",
            dependencies: [
                "InnoRouterMacrosPlugin",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "InnoRouterMacrosBehaviorTests",
            dependencies: [
                "InnoRouterMacros",
                "InnoRouterCore",
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "InnoRouterTestingTests",
            dependencies: [
                "InnoRouterTesting",
                "InnoRouter",
                "InnoRouterSwiftUI",
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
