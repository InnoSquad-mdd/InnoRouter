# InnoRouter Principle Scorecard

This scorecard maps the current implementation to SwiftUI philosophy, SOLID, typed execution semantics, and the repository’s release/documentation discipline.

## Architecture mapping

| Axis | Current state | Evidence | Status |
|---|---|---|---|
| Core semantics | Typed route stack, command algebra, batch, and transaction execution | `Sources/InnoRouterCore` | Enforced |
| SwiftUI authority | Stack, split-detail, and modal surfaces are separated by host/store responsibility | `Sources/InnoRouterSwiftUI` | Enforced |
| Deep-link planning | URL matching and policy flow are explicit, typed, and replay-friendly | `Sources/InnoRouterDeepLink` | Enforced |
| App boundary effects | Navigation-only effects and deep-link effects are split cleanly | `Sources/InnoRouterNavigationEffects`, `Sources/InnoRouterDeepLinkEffects` | Enforced |
| Host-less testability | `NavigationTestStore`, `ModalTestStore`, and `FlowTestStore` expose a shippable Swift Testing harness over the public observation surface | `Sources/InnoRouterTesting` | Enforced |
| Coordinator composition | `ChildCoordinator` + `parent.push(child:) -> Task<Result?, Never>` give child → parent finish chaining with inline `await`, symmetric with SwiftUI authority boundaries | `Sources/InnoRouterSwiftUI/ChildCoordinator.swift`, `Docs/design-child-coordinator-handoff.md` | Enforced |
| Documentation | README and DocC coexist; module-level docs live beside sources | `README.md`, `Sources/*/*.docc` | Enforced |
| Release discipline | Semver tags, DocC publishing, and GitHub Releases share one flow | `.github/workflows/release.yml`, `RELEASING.md` | Enforced |

## SwiftUI philosophy

Positive alignment:

- Views emit `NavigationIntent` and `ModalIntent` instead of mutating stores directly.
- Stack routing, modal routing, and split-detail routing are different authorities rather than one overloaded state bucket.
- Environment wiring is fail-fast.
- `NavigationStore` and `ModalStore` expose explicit authority boundaries rather than hiding side effects in views.

Intentional trade-offs:

- `NavigationStore`, `ModalStore`, and `Coordinator` remain reference types because they represent shared authority, not ephemeral local state.
- Column visibility and sidebar selection remain app-owned instead of being absorbed into router state.

## Execution model

InnoRouter deliberately exposes three semantics instead of collapsing them:

- `.sequence`: left-to-right command algebra
- `executeBatch`: observation batching
- `executeTransaction`: atomic all-or-nothing commit

This separation improves reasoning and testing because each semantic has one clear contract.

## Documentation and release quality

The repository now treats documentation as a first-class artifact:

- `.md` files explain repository-level usage and release process
- `.docc` catalogs cover module-level concepts and symbols
- CI validates DocC generation on every PR
- CD publishes versioned docs and a `latest` alias from the same semver tag that cuts the library release

## Current strengths

- Typed failures stay in normal control flow.
- Middleware cancellation reasons are explicit.
- Deep-link matcher diagnostics catch ambiguity without changing precedence.
- Modal routing exposes the same middleware surface as navigation (`ModalMiddleware`, `AnyModalMiddleware`, CRUD API, `onMiddlewareMutation`, `onCommandIntercepted`), so gating and analytics hooks compose symmetrically across both authorities.
- `FlowStore<R>` represents push + sheet + cover progression as a single `[RouteStep<R>]` value, delegating execution to the existing `NavigationStore` + `ModalStore` without removing their individual authorities.
- `InnoRouterTesting` ships `NavigationTestStore` / `ModalTestStore` / `FlowTestStore` as a shippable Swift-Testing-native harness with TCA-style strict exhaustivity, so consumers no longer need `@testable import` to assert routing behaviour.
- `NavigationStoreConfiguration.onPathMismatch` surfaces path-reconciliation telemetry publicly, completing the set of public observation hooks.
- Child coordinators chain to parents through `ChildCoordinator` + `Coordinator.push(child:) -> Task<Result?, Never>`, so parent flows can `await` child finish values inline without hand-rolled continuation plumbing.
- Case-typed destination bindings (`NavigationStore.binding(case:)`, `ModalStore.binding(case:style:)`) route every SwiftUI set through the existing command pipeline so middleware and telemetry observe them identically to direct `execute(...)`.
- High-frequency navigation intents (`replaceStack`, `backOrPush`, `pushUniqueRoot`) compose from existing `NavigationCommand` primitives so the engine stays minimal while app code stays declarative.
- Human-facing examples and smoke fixtures are intentionally separated.

## Remaining trade-offs

- SwiftUI shell state such as split column visibility is still app-owned.
- Alerts and confirmation dialogs remain outside the framework scope.
- Core middleware stays synchronous by design; async policy belongs at effect boundaries.

These are intentional scope boundaries, not accidental omissions.
