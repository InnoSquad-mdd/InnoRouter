# Competitive Analysis and Improvement Roadmap

_Last updated: 2026-04-19 · Base: main @ `e19f03b5` (post PR #10/#11 merge)_

This document positions InnoRouter against comparable SwiftUI navigation
libraries and derives a prioritised improvement backlog from the gaps.

- Scope: libraries that own SwiftUI stack/modal navigation state at roughly
  the same level of the stack as InnoRouter.
- Audience: maintainers and release planners. Not a public marketing doc.
- Source: April 2026 repo inspection + repo/readme scans of each comparable
  library.

## 1. Position statement

> InnoRouter is a **typed stack + explicit command execution + declarative
> deep-link planner + observable middleware** SwiftUI-native router. It
> sits between FlowStacks' coordinator ergonomics and TCA's typed
> observability, without forcing adoption of a full app architecture.

Platform floor (iOS 18 / Swift 6.2) and mandatory strict concurrency are
the most aggressive among peers — higher adoption cost in exchange for a
smaller, simpler implementation surface.

## 2. Feature matrix

Legend: ✅ first-class · ⚠ partial / opt-in · ❌ absent.

| Axis | **InnoRouter** | **TCA** | **swift-navigation** | **FlowStacks** | **TCACoordinators** | **Stinsen** | **SwiftfulRouting** | **LinkNavigator** |
|---|---|---|---|---|---|---|---|---|
| Typed route | ✅ `Route` protocol | ✅ `StackState<Elem>` | ✅ `@CasePathable` enum | ✅ `Route<Screen>` | ✅ (inherits TCA) | ⚠ DSL, not value-typed | ⚠ closure-based | ❌ URL string |
| Unified push + sheet + cover stack | ❌ separate stores | ❌ nested presents | ❌ | ✅ **single array** | ✅ | ⚠ | ⚠ | ⚠ |
| Middleware / interception | ✅ willExecute/didExecute + cancel | ✅ reducer composition | ❌ | ❌ | ✅ (via TCA) | ❌ | ❌ | ❌ |
| Deep link pipeline | ✅ Matcher + Pipeline + AuthPolicy + Outcome | ⚠ hand-hydrate | ❌ | ✅ rebuild path | ✅ | ⚠ manual | ❌ | ✅ URL-first |
| Public observability hooks | ✅ onChange / Batch / Transaction / MiddlewareMutation | ✅ TestStore covers it | ⚠ `observe { }` | ❌ | ✅ | ❌ | ❌ | ❌ |
| Batch + Transaction split | ✅ two models | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Validator / Mismatch policy | ✅ `RouteStackValidator`, `NavigationPathMismatchPolicy` | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Host-less testing | ⚠ `@testable` + TelemetryRecorder injection | ✅ **`TestStore`** | ✅ assert on model | ✅ value-typed arrays | ✅ | ❌ | ⚠ | ⚠ |
| Macros | ✅ `@Routable`, `@CasePathable` | ✅ `@Reducer`, `@Presents`, `@CasePathable` | ✅ `@CasePathable` | ❌ | (TCA) | ❌ | ❌ | ❌ |
| Swift 6 strict concurrency | ✅ **enforced per module** | ✅ | ✅ | ⚠ in progress | ⚠ | ❌ | ✅ | ✅ |
| iOS floor | **18+** | 13+ / 17+ for Observation | 13+ | 16+ | 13+ | 14+ | 17+ | 16+ |
| Cross-surface (UIKit / AppKit) | ❌ SwiftUI only | ⚠ | ✅ **4 products** | ❌ | ⚠ | ⚠ | ❌ | ❌ |
| Coordinator composition (child → parent) | ⚠ protocol only | ✅ reducer `forEach` | ❌ | ✅ | ✅ | ✅ | ⚠ | ⚠ |

## 3. Head-to-head takeaways

### vs TCA — 14.5k★
- **Lead**: adoption cost, build time, view-code neutrality (TCA is
  all-or-nothing), typed deep-link outcomes, batch ↔ transaction split.
- **Lag**: no `TestStore`-grade exhaustive host-less harness, smaller
  reference/documentation surface, macro ecosystem (`@Reducer`/`@Presents`)
  is more mature.

### vs swift-navigation — 2.3k★ (PointFree)
- **Lead**: full stack authority, middleware, pipeline. swift-navigation
  is bindings-only.
- **Lag**: no cross-surface story (UIKit / AppKit / visionOS / Linux).
  Small teams can still ship with swift-navigation + a hand-rolled router.

### vs FlowStacks — 967★
- **Lead**: typed results, middleware, pipeline, validator. FlowStacks is
  pure path manipulation.
- **Lag**: **no single-array representation of push + sheet + cover** —
  FlowStacks' signature win. InnoRouter splits `NavigationStore` and
  `ModalStore`, so the whole flow cannot be serialised as one value.

### vs TCACoordinators — 498★
- **Lead**: no TCA dependency, lower learning curve,
  `DeepLinkCoordinationOutcome` surfaces coordinator-level observability.
- **Lag**: built-in coordinator-composition primitives (child → parent
  chain, "back to root across coordinators") are absent.

### vs Stinsen — 960★ (legacy)
- **Lead**: every axis. NavigationStack-era, Observation, Sendable,
  modern concurrency.
- **Lag**: none. Reference only.

### vs SwiftfulRouting — 960★
- **Lead**: typed routing, middleware, explicit state model.
  SwiftfulRouting is imperative `router.showScreen { }`.
- **Lag**: indie "one import, go" ergonomics — InnoRouter asks for route
  modelling up front.

### vs LinkNavigator — 432★
- **Lead**: type safety (LinkNavigator uses string paths).
- **Lag**: string-path UX (`navigator.next(paths: ["a","b"])`) is
  exceptionally strong for deep-link rehydration. InnoRouter's pipeline
  resolves a URL to a single plan; multi-step path rehydration still
  requires hand-rolling commands.

## 4. Improvement backlog

Ordered by business impact on positioning. Each item is a separate piece
of work and should become its own PR.

### P0 — Fills a positioning-critical gap

#### P0-1 Host-less test harness (`NavigationTestStore`)

Today, verifying command/middleware/transition ordering requires
`@testable import InnoRouterSwiftUI` + manual `TelemetryRecorder`
injection. TCA's `TestStore` is the benchmark: every push/pop/dismiss
action is asserted, and unasserted events fail teardown.

Shape:

- Public `NavigationTestStore<R>` wrapping an internal `NavigationStore`.
- `assertPush(_:)`, `assertPop()`, `assertBatch(_:)`, `assertMutation(_:)`.
- Subscribes to `onChange`, `onBatchExecuted`, `onTransactionExecuted`,
  `onMiddlewareMutation` internally.
- Fails on unasserted events at deinit.

Unlocks: parity claim with TCA's testability story.

#### P0-2 Unified flow stack (`FlowStack<R>` / `FlowStore<R>`) — **Shipped**

Current architecture (separate `NavigationStore` + `ModalStore`) is
clean but cannot serialise a whole flow (e.g. a login onboarding across
push + sheet + cover) as one value. This is FlowStacks' headline win.

Shape (landed):

- `enum RouteStep<R> { case push(R), sheet(R), cover(R) }` in
  `InnoRouterCore`.
- `FlowStore<R>` (`InnoRouterSwiftUI`) owns an inner `NavigationStore`
  + `ModalStore` and exposes `path: [RouteStep<R>]` as the single
  source of truth. `FlowIntent` + `FlowPlan` are the public entry points.
- `FlowHost` composes `ModalHost` over `NavigationHost` and injects an
  `AnyFlowIntentDispatcher` for environment dispatch.
- Invariants are enforced with explicit rejection reasons
  (`pushBlockedByModalTail`, `invalidResetPath`, `middlewareRejected`).

Unlocks: flow-level deep links, restoration, replay.

#### P0-3 Deep-link path rehydration

`DeepLinkPipeline` currently resolves a URL into a single
`NavigationPlan`. URLs like `myapp://home/detail/123/comments/456`
should map type-safely to
`[push(.home), push(.detail("123")), push(.comments("456"))]`.

Shape:

- `DeepLinkPathResolver<R>`: segment list → `[NavigationCommand<R>]`.
- Trie-based matching or a chain of per-segment resolvers.
- Integrates with `DeepLinkPipeline` so `.plan` can carry a
  multi-command plan driven by path structure, not just a single route.

Unlocks: genuine path-based deep links competitive with LinkNavigator.

### P1 — Meaningful feature gap

#### P1-1 Coordinator composition primitives

Child coordinators cannot cleanly report finish/cancel to a parent.
This is FlowStacks' and TCACoordinators' daily ergonomics.

Shape:

- `ChildCoordinator<Parent, Result>` with `onFinish(Result)` callback.
- `parent.push(child:)` returning `Task<Result>` for async await on
  child completion.

#### P1-2 Typed destination bindings

`@CasePathable` exists, but public `.sheet(item:)`-style helpers per
enum case are not provided on the store.

Shape:

- `NavigationStore<R>.binding(case: CasePath<R, Detail>) -> Binding<Detail?>`.
- Mirror for `ModalStore`.

#### P1-3 Named stack intents

Add `NavigationIntent.replaceStack([R])`, `.backOrPush(R)`,
`.pushUniqueRoot(R)`, and similar high-frequency intents. These
currently require hand-composed commands.

#### P1-4 `ModalStore` middleware — **Shipped**

`NavigationStore` had middleware; `ModalStore` did not. Apps routinely
need "log before presenting" / "gate by entitlement" hooks.

Shape (landed):

- `ModalMiddleware` protocol + `AnyModalMiddleware<M>` in
  `InnoRouterCore`, mirroring `NavigationMiddleware`.
- `ModalStore` now routes every `.present` / `.dismissCurrent` /
  `.dismissAll` through `execute(_:) -> ModalExecutionResult<M>`, with
  `willExecute` / `didExecute` participant discipline identical to
  navigation.
- Public middleware CRUD on `ModalStore`
  (`addMiddleware`/`insertMiddleware`/`removeMiddleware`/`replaceMiddleware`/`moveMiddleware`)
  plus `onMiddlewareMutation` and `onCommandIntercepted` config hooks
  for analytics.

### P2 — Quality of life

#### P2-1 Unified telemetry stream

`onMiddlewareMutation` is public. The remaining internal events
(pathMismatch, batch executed, transaction committed/rolled back) should
be unified into a single public `AsyncStream<NavigationEvent<R>>` so
analytics pipelines wire up in one place instead of N callbacks.

#### P2-2 `Codable` route stacks + state restoration

Opt-in `Codable` on `RouteStack<R>` plus a `StatePersistence` helper for
launch-time restoration. TCA and FlowStacks both offer this.

#### P2-3 UIKit escape hatch

A minimal UIKit module that bidirectionally binds `NavigationStore` to
`UINavigationController`, to ease incremental adoption in existing UIKit
apps. Benchmark: swift-navigation's multi-surface modules.

#### P2-4 DocC walkthroughs

Existing DocC is symbol-level. Add tutorial-style articles (e.g. login
onboarding, deep link reconciliation) in the `.docc` catalogs. PointFree
is the reference for style.

### P3 — Nice to have

- **Macro diagnostics**: `@Routable` error messages and FixIts.
- **Command algebra extensions**: `.whenCancelled(then:)`, `.throttle`,
  `.debounce` for dedupe / UX smoothing.
- **`NavigationPlugin` protocol**: bundle lifecycle hooks so logging /
  analytics / crash reporting integrate via a plugin surface instead of
  scattered closures.
- **Property-based tests**: leverage parameterised Swift Testing for
  `RouteStack` / `NavigationEngine` invariants.

## 5. Summary backlog table

| Priority | Item | Impact | Difficulty |
|---|---|---|---|
| P0 | NavigationTestStore | positioning-decisive | large |
| P0 | Unified FlowStack (push + sheet + cover) | positioning | medium–large |
| P0 | Deep link path rehydration | deep-link selling point | medium |
| P1 | Coordinator composition | coordinator UX | medium |
| P1 | Typed destination bindings | ergonomics | small |
| P1 | Named stack intents | ergonomics | small |
| P1 | ModalStore middleware | symmetry | small |
| P2 | Unified telemetry stream | analytics unification | small |
| P2 | `Codable` + restoration | real-app requirement | medium |
| P2 | UIKit escape hatch | adoption path | large |
| P2 | DocC walkthroughs | learning curve | small–medium |
| P3 | Macro diagnostics, algebra, plugin, PBT | polish | small |

## 6. Suggested next work

- **Highest independent payoff**: P0-1 `NavigationTestStore`. No
  architectural churn, directly closes the largest gap versus TCA.
- **Highest leverage cluster**: P1-2 + P1-3 + P1-4. Small, compatible,
  collectively raise the daily-use ergonomics bar.
- **Largest architectural decision**: P0-2 `FlowStack`. Needs a design
  round first — whether to keep the two-store split internally or merge.

## 7. Sources

- InnoRouter repo, `main @ e19f03b5` (2026-04-19).
- [pointfreeco/swift-composable-architecture](https://github.com/pointfreeco/swift-composable-architecture)
- [pointfreeco/swift-navigation](https://github.com/pointfreeco/swift-navigation)
- [johnpatrickmorgan/FlowStacks](https://github.com/johnpatrickmorgan/FlowStacks)
- [johnpatrickmorgan/TCACoordinators](https://github.com/johnpatrickmorgan/TCACoordinators)
- [rundfunk47/stinsen](https://github.com/rundfunk47/stinsen)
- [SwiftfulThinking/SwiftfulRouting](https://github.com/SwiftfulThinking/SwiftfulRouting)
- [forXifLess/LinkNavigator](https://github.com/forXifLess/LinkNavigator)
