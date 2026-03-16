// swift-tools-version: 6.2

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "InnoRouter",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .tvOS(.v18),
        .watchOS(.v11)
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

        // MARK: - Example Smoke Targets
        .target(
            name: "InnoRouterStandaloneExampleSmoke",
            dependencies: ["InnoRouter"],
            path: "ExamplesSmoke",
            exclude: ["CoordinatorSmoke.swift", "DeepLinkSmoke.swift", "SplitCoordinatorSmoke.swift", "AppShellSmoke.swift", "ModalSmoke.swift"],
            sources: ["StandaloneSmoke.swift"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "InnoRouterCoordinatorExampleSmoke",
            dependencies: ["InnoRouter"],
            path: "ExamplesSmoke",
            exclude: ["StandaloneSmoke.swift", "DeepLinkSmoke.swift", "SplitCoordinatorSmoke.swift", "AppShellSmoke.swift", "ModalSmoke.swift"],
            sources: ["CoordinatorSmoke.swift"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "InnoRouterDeepLinkExampleSmoke",
            dependencies: ["InnoRouter"],
            path: "ExamplesSmoke",
            exclude: ["StandaloneSmoke.swift", "CoordinatorSmoke.swift", "SplitCoordinatorSmoke.swift", "AppShellSmoke.swift", "ModalSmoke.swift"],
            sources: ["DeepLinkSmoke.swift"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "InnoRouterSplitCoordinatorExampleSmoke",
            dependencies: ["InnoRouter"],
            path: "ExamplesSmoke",
            exclude: ["StandaloneSmoke.swift", "CoordinatorSmoke.swift", "DeepLinkSmoke.swift", "AppShellSmoke.swift", "ModalSmoke.swift"],
            sources: ["SplitCoordinatorSmoke.swift"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "InnoRouterAppShellExampleSmoke",
            dependencies: ["InnoRouter"],
            path: "ExamplesSmoke",
            exclude: ["StandaloneSmoke.swift", "CoordinatorSmoke.swift", "DeepLinkSmoke.swift", "SplitCoordinatorSmoke.swift", "ModalSmoke.swift"],
            sources: ["AppShellSmoke.swift"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "InnoRouterModalExampleSmoke",
            dependencies: ["InnoRouter"],
            path: "ExamplesSmoke",
            exclude: ["StandaloneSmoke.swift", "CoordinatorSmoke.swift", "DeepLinkSmoke.swift", "SplitCoordinatorSmoke.swift", "AppShellSmoke.swift"],
            sources: ["ModalSmoke.swift"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),

        // MARK: - Macro Declarations (Public API)
        .target(
            name: "InnoRouterMacros",
            dependencies: ["InnoRouterCore", "InnoRouterMacrosPlugin"],
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
            dependencies: ["InnoRouter", "InnoRouterEffects", "InnoRouterSwiftUI"]
        ),
        .testTarget(
            name: "InnoRouterMacrosTests",
            dependencies: [
                "InnoRouterMacrosPlugin",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
