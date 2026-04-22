# InnoRouterSwiftUI

SwiftUI hosts, stores, modal routing, coordinators, and environment intent dispatch for InnoRouter.

## Overview

`InnoRouterSwiftUI` adapts the core execution model to SwiftUI.

This module owns:

- `NavigationStore`
- `NavigationHost` and `NavigationSplitHost` (watchOS not supported for split host)
- `CoordinatorHost` and `CoordinatorSplitHost` (watchOS not supported for split host)
- `ModalStore` and `ModalHost`
- `NavigationIntent` and `ModalIntent`
- `EnvironmentNavigationIntent` and `EnvironmentModalIntent`
- `FlowCoordinator` and `TabCoordinator`
- `SceneDeclaration`, `SceneRegistry`
- `SceneStore`, `SceneHost`, `SceneAnchor` (visionOS only)
- `innoRouterOrnament(_:content:)` view modifier (no-op off visionOS)

The guiding rule is simple: views emit intent, stores own transition authority, and hosts bridge system UI state back into those authorities.

## Platform support

InnoRouter ships on every Apple platform it currently supports:

| Capability | iOS | iPadOS | macOS | tvOS | watchOS | visionOS |
|---|---|---|---|---|---|---|
| `NavigationHost` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `NavigationSplitHost` / `CoordinatorSplitHost` | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |
| `ModalHost` `.sheet` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `ModalHost` `.fullScreenCover` (native) | ✅ | ✅ | ⚠ degrades to `.sheet` | ✅ | ⚠ degrades to `.sheet` | ⚠ degrades to `.sheet` |
| `TabCoordinator.badge` | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ |
| `SceneStore`, `SceneHost` | — | — | — | — | — | ✅ |
| `innoRouterOrnament` | no-op | no-op | no-op | no-op | no-op | ✅ |

## Topics

### Essentials

- <doc:NavigationStore-and-Hosts>
- <doc:Split-Modal-and-Composition>
- <doc:Coordinators-and-Environment-Intent>

### Tutorials

- <doc:Tutorial-LoginOnboarding>
- <doc:Tutorial-DeepLinkReconciliation>
- <doc:Tutorial-MiddlewareComposition>
- <doc:Tutorial-MigratingFromNestedHosts>
- <doc:Tutorial-Throttling>
- <doc:Tutorial-StoreObserver>
- <doc:Tutorial-VisionOSScenes>
