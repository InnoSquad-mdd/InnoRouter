# InnoRouter v2 Principle Scorecard

This scorecard maps v2 implementation decisions to SwiftUI philosophy, SOLID principles, Swift API Design Guidelines, and `ios-native-skills` rules.

## Rule-to-Code Mapping

| Axis | Rule | Implementation Evidence | Status |
|---|---|---|---|
| SwiftUI | `swiftui-navigation` | `@EnvironmentNavigationIntent` + intent-first dispatch in `/Users/changwoo.son/Developer/InnoSquad/InnoRouter/Sources/InnoRouterSwiftUI/NavigatorEnvironment.swift` and host injection in `/Users/changwoo.son/Developer/InnoSquad/InnoRouter/Sources/InnoRouterSwiftUI/NavigationHost.swift` | Enforced |
| SwiftUI | `swiftui-state-management` | `NavigationStore.state` as source of truth in `/Users/changwoo.son/Developer/InnoSquad/InnoRouter/Sources/InnoRouterSwiftUI/NavigationStore.swift` | Enforced |
| SwiftUI | `swiftui-view-composition` | Views emit intent only in `/Users/changwoo.son/Developer/InnoSquad/InnoRouter/Examples/StandaloneExample.swift` and `/Users/changwoo.son/Developer/InnoSquad/InnoRouter/Examples/CoordinatorExample.swift` | Enforced |
| SOLID | `arch-single-responsibility` | Coordinator public surface focused on `send(_:)` / `handle(_:)` in `/Users/changwoo.son/Developer/InnoSquad/InnoRouter/Sources/InnoRouterSwiftUI/Coordinator.swift` | Enforced |
| SOLID | `arch-protocol-oriented` | `Navigator` protocol boundary in `/Users/changwoo.son/Developer/InnoSquad/InnoRouter/Sources/InnoRouterCore/Navigator.swift` | Enforced |
| SOLID | `arch-dependency-injection` | Effect handlers depend on generic `Navigator` init in `/Users/changwoo.son/Developer/InnoSquad/InnoRouter/Sources/InnoRouterEffects/NavigationEffectHandler.swift` and `/Users/changwoo.son/Developer/InnoSquad/InnoRouter/Sources/InnoRouterEffects/DeepLinkEffectHandler.swift` | Enforced |
| SOLID | `arch-error-handling` | Typed deep-link effect outcomes (`invalidURL`, `missingDeepLinkURL`, `noPendingDeepLink`) in `/Users/changwoo.son/Developer/InnoSquad/InnoRouter/Sources/InnoRouterEffects/DeepLinkEffectHandler.swift` | Enforced |
| Concurrency | `concurrency-main-actor` | UI integration and handlers annotated with `@MainActor` across SwiftUI/effects modules | Enforced |
| Concurrency | `concurrency-sendable` | Deep-link decisions, plans, and parameters are `Sendable` in `/Users/changwoo.son/Developer/InnoSquad/InnoRouter/Sources/InnoRouterDeepLink` | Enforced |
| Testing | `test-methodology` | Scenario coverage in `/Users/changwoo.son/Developer/InnoSquad/InnoRouter/Tests/InnoRouterTests/InnoRouterTests.swift` | Enforced |
| InnoSquad | `innosquad-innorouter` | Route stack/command engine/store/coordinator/deeplink pipeline integration preserved across Core/SwiftUI/DeepLink modules | Enforced |
| InnoSquad | `innosquad-integration` | Effect integration remains layered in `/Users/changwoo.son/Developer/InnoSquad/InnoRouter/Sources/InnoRouterEffects` and umbrella glue in `/Users/changwoo.son/Developer/InnoSquad/InnoRouter/Sources/InnoRouterUmbrella` | Enforced |

## Swift API Design Guide Checklist

- Public type names are nouns (`NavigationStore`, `DeepLinkPipeline`, `NavigationIntent`).
- Public methods use verb phrases (`send(_:)`, `execute(_:)`, `resumePendingDeepLink()`).
- Public Bool names follow prefix rule (`is*`, `has*`, `can*`, `should*`).
- Intent APIs read naturally in call-site form.

## External Framework Comparison (v2)

| Framework | Adopted | Not Adopted |
|---|---|---|
| SwiftNavigation | Typed state/route transitions | Observation-specific runtime coupling |
| TCACoordinators | Deterministic execution controls (`stopOnFailure`) | TCA runtime dependency |
| FlowStacks | Plan-based deep-link replay | Stack-internal API coupling |
| Stinsen | Host-scoped coordinator boundaries | Container/runtime ownership coupling |

## Quality Gates

Run `/Users/changwoo.son/Developer/InnoSquad/InnoRouter/scripts/principle-gates.sh` to validate:
- tests
- naming/deprecation gates
- SwiftUI surface purity gates
- deep-link fallback removal
- public Bool naming rule
