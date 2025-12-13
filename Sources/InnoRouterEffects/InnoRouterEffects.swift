// MARK: - InnoRouterEffects.swift
// InnoRouterEffects - Effect Integration
// Copyright © 2025 Inno Squad. All rights reserved.

@_exported import InnoRouterCore
@_exported import InnoRouterDeepLink

// MARK: - Module Overview
//
// InnoRouterEffects provides integration points between InnoRouterCore and effect-driven architectures.
//
// ## Key Types
// - `NavigationEffectHandler`: Execute NavCommand as Effects
// - `DeepLinkEffectHandler`: Handle deep links as Effects
// - `NavigationEffect`: Protocol for Effects containing NavCommand
// - `DeepLinkEffect`: Protocol for Effects containing deep links
//
// ## Usage with InnoFlow (example)
//
// ```swift
// @InnoFlow
// struct ProductFeature {
//     // Dependencies
//     let navigationHandler: NavigationEffectHandler<ProductRoute>
//
//     // Effect
//     enum Effect: Sendable {
//         case navigate(Navigation<ProductRoute>)
//         case loadProducts
//     }
//
//     // Reduce
//     func reduce(state: inout State, action: Action) -> Effect? {
//         switch action {
//         case .productTapped(let id):
//             return .navigate(.push(.detail(id: id)))
//         case .backTapped:
//             return .navigate(.pop)
//         }
//     }
//
//     // Handle Effect
//     func handle(effect: Effect) async -> EffectOutput<Action> {
//         switch effect {
//         case .navigate(let command):
//             await navigationHandler.execute(command)
//             return .none
//         case .loadProducts:
//             // ...
//             return .none
//         }
//     }
// }
// ```
//
// ## Comparison: Standalone vs Effect-driven
//
// | Feature | InnoRouter (Standalone) | InnoRouterEffects |
// |---------|-------------------------|-------------------|
// | Import | `import InnoRouter` | `import InnoRouterEffects` |
// | Navigation | `router.push()` | `store.send(.navigate(.push()))` |
// | State | Direct Router | InnoFlow State |
// | DeepLink | DeepLinkHandler | DeepLinkEffectHandler |
// | Testability | Manual | InnoFlow TestStore |
