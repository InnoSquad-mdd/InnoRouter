# Competitive Analysis and Improvement Roadmap

_Last updated: 2026-04-20 · Base: main @ `d1d89920` (post PR #12 merge + atomic-commit follow-up `47467b50`)_

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
| Unified push + sheet + cover stack | ✅ `FlowStore<R>` + `[RouteStep<R>]` | ❌ nested presents | ❌ | ✅ **single array** | ✅ | ⚠ | ⚠ | ⚠ |
| Middleware / interception | ✅ willExecute/didExecute + cancel **on both Navigation and Modal** | ✅ reducer composition | ❌ | ❌ | ✅ (via TCA) | ❌ | ❌ | ❌ |
| Deep link pipeline | ✅ Matcher + Pipeline + AuthPolicy + Outcome | ⚠ hand-hydrate | ❌ | ✅ rebuild path | ✅ | ⚠ manual | ❌ | ✅ URL-first |
| Public observability hooks | ✅ onChange / Batch / Transaction / MiddlewareMutation | ✅ TestStore covers it | ⚠ `observe { }` | ❌ | ✅ | ❌ | ❌ | ❌ |
| Batch + Transaction split | ✅ two models | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Validator / Mismatch policy | ✅ `RouteStackValidator`, `NavigationPathMismatchPolicy` | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Host-less testing | ✅ `InnoRouterTesting` (Navigation / Modal / Flow) | ✅ **`TestStore`** | ✅ assert on model | ✅ value-typed arrays | ✅ | ❌ | ⚠ | ⚠ |
| Macros | ✅ `@Routable`, `@CasePathable` | ✅ `@Reducer`, `@Presents`, `@CasePathable` | ✅ `@CasePathable` | ❌ | (TCA) | ❌ | ❌ | ❌ |
| Swift 6 strict concurrency | ✅ **enforced per module** | ✅ | ✅ | ⚠ in progress | ⚠ | ❌ | ✅ | ✅ |
| iOS floor | **18+** | 13+ / 17+ for Observation | 13+ | 16+ | 13+ | 14+ | 17+ | 16+ |
| Cross-surface (UIKit / AppKit) | ❌ SwiftUI only | ⚠ | ✅ **4 products** | ❌ | ⚠ | ⚠ | ❌ | ❌ |
| Coordinator composition (child → parent) | ✅ `ChildCoordinator` + `parent.push(child:) -> Task<Result?>` | ✅ reducer `forEach` | ❌ | ✅ | ✅ | ✅ | ⚠ | ⚠ |
| Case-typed destination bindings | ✅ `store.binding(case:)` on Nav + Modal | ⚠ via `@Presents` | ✅ `@CasePathable` | ⚠ | ⚠ | ❌ | ❌ | ❌ |

## 3. Head-to-head takeaways

### vs TCA — 14.5k★
- **Lead**: adoption cost, build time, view-code neutrality (TCA is
  all-or-nothing), typed deep-link outcomes, batch ↔ transaction split.
- **Lag (narrowed)**: the host-less gap is closed by the new
  `InnoRouterTesting` product, which ships
  `NavigationTestStore` / `ModalTestStore` / `FlowTestStore` with
  TCA-style strict exhaustivity and Swift Testing `Issue.record`
  reporting — no `@testable import` required. Remaining lag: smaller
  reference/documentation surface, macro ecosystem
  (`@Reducer`/`@Presents`) is more mature.

### vs swift-navigation — 2.3k★ (PointFree)
- **Lead**: full stack authority, middleware, pipeline. swift-navigation
  is bindings-only.
- **Lag**: no cross-surface story (UIKit / AppKit / visionOS / Linux).
  Small teams can still ship with swift-navigation + a hand-rolled router.

### vs FlowStacks — 967★
- **Lead**: typed results, middleware (on _both_ Navigation and Modal),
  pipeline, validator. FlowStacks is pure path manipulation.
- **Lag (narrowed)**: `FlowStore<R>` now exposes
  `path: [RouteStep<R>]` as a single source of truth over the internal
  `NavigationStore` + `ModalStore`, so push + sheet + cover serialise as
  one value. Remaining gap: `RouteStep` / `FlowPlan` are not yet
  `Codable`, so state restoration still requires hand-rolling a plan.
  Tracked under P0-3 and P2-2.

### vs TCACoordinators — 498★
- **Lead**: no TCA dependency, lower learning curve,
  `DeepLinkCoordinationOutcome` surfaces coordinator-level observability.
  `ChildCoordinator` + `parent.push(child:) -> Task<Result?, Never>`
  (#14) now provides child → parent finish chaining with inline
  `await` on the child result.
- **Lag (narrowed)**: "back to root across coordinators" still
  requires manual cleanup. Remaining P3 item: `Task` cancellation
  propagation parent → child.

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

#### P0-1 Host-less test harness (`NavigationTestStore`) — **Shipped**

`InnoRouterTesting` (new shippable product) closes the last TCA-parity
gap. Consumers add `.product(name: "InnoRouterTesting", package:
"InnoRouter")` to a test target — no `@testable import` needed.

Shape (landed):

- `NavigationTestStore<R>`, `ModalTestStore<M>`, `FlowTestStore<R>`
  — each wraps a production store and transparently subscribes to
  every public observation callback.
- Typed receivers: `receiveChange`, `receiveBatch`,
  `receiveTransaction`, `receiveMiddlewareMutation`,
  `receivePathMismatch`, `receivePresented`, `receiveDismissed`,
  `receiveQueueChanged`, `receiveIntercepted`, `receivePathChanged`,
  `receiveIntentRejected`, `receiveNavigation`, `receiveModal`.
- TCA-style exhaustivity: strict by default, unasserted events at
  deinit fire Swift Testing `Issue.record`. `.off` mode preserves
  per-call asserts but silences the final drain check.
- New `NavigationStoreConfiguration.onPathMismatch` public callback
  completes public observability so no harness internals are needed.
- `FlowTestStore` wraps both inner stores so one test can assert an
  intent's complete chain (`.navigation(...)` + `.modal(...)` +
  `.pathChanged` / `.intentRejected` on a single FIFO queue).

Unlocks: TCA-parity host-less testability claim + durable regression
coverage for middleware/telemetry without reaching for `@testable`.

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
- Atomic commits (`47467b50`): every `FlowIntent` now previews both
  inner stores first (`NavigationStore.previewFlowCommand` +
  `ModalStore.previewFlowCommand`) and only commits when every leg
  succeeds, so a mid-flight middleware cancellation cannot leave the
  composite in a torn state.

Unlocks: flow-level deep links, restoration, replay. Next gap is
serialisation (Codable `RouteStep` / `FlowPlan`) and pipeline
integration — tracked under P0-3 and P2-2.

#### P0-3 Deep-link path rehydration + `FlowPlan` integration

`DeepLinkPipeline` currently resolves a URL into a single
`NavigationPlan` containing `[NavigationCommand<R>]`. Two shortcomings:

1. URLs like `myapp://home/detail/123/comments/456` should map
   type-safely to
   `[push(.home), push(.detail("123")), push(.comments("456"))]` —
   today this requires a hand-rolled matcher per depth.
2. With `FlowStore<R>` landed, deep links cannot target modal tails.
   `NavigationPlan` only carries push commands, so a URL cannot open
   a sheet/cover as its terminal step.

Shape:

- `DeepLinkPathResolver<R>`: segment list → `[NavigationCommand<R>]`.
  Trie-based matching or a chain of per-segment resolvers.
- Extend `DeepLinkDecision` with a `.flowPlan(FlowPlan<R>)` case
  alongside `.plan(NavigationPlan<R>)`, or introduce a
  `FlowDeepLinkPipeline` that returns `FlowPlan<R>` directly.
- Wire `FlowStore.apply(_ plan:)` into `DeepLinkEffectHandler` so a
  URL can hydrate a whole push + sheet sequence in one call.
- Prerequisite: `RouteStep` / `FlowPlan` `Codable` conformance
  (currently scoped under P2-2 — **promote to P0-3 prerequisite**).

Unlocks: genuine path-based deep links competitive with LinkNavigator,
plus modal-terminating URLs that the `FlowStore` can rehydrate
atomically.

### P1 — Meaningful feature gap

#### P1-1 Coordinator composition primitives — **Shipped (#14)**

Child coordinators can now cleanly report finish/cancel back to a
parent, closing the FlowStacks / TCACoordinators ergonomics gap.

Shape (landed):

- `ChildCoordinator` protocol in `InnoRouterSwiftUI` with associated
  `Result` type + `onFinish` / `onCancel` callback hooks.
- `Coordinator.push(child:) -> Task<Child.Result?, Never>` lets a
  parent `await` the child's finish value inline. Callbacks are
  installed synchronously through `AsyncStream.makeStream()` so the
  child can fire `onFinish` at any point (including before the
  parent's `await`), avoiding a `@MainActor` re-entrancy deadlock.
- Design rationale in `Docs/design-child-coordinator-handoff.md`.

Remaining gap (tracked as P3): `Task` cancellation propagation from
parent → child.

#### P1-2 Typed destination bindings — **Shipped (#14)**

`@CasePathable` now has `.sheet(item:)`-style helpers per enum case
exposed on both stores.

Shape (landed):

- `NavigationStore<R>.binding(case: CasePath<R, Detail>) -> Binding<Detail?>`.
- `ModalStore<M>.binding(case:style:)` mirror scoped per presentation
  style.
- `CasePath` moved from `InnoRouterMacros` to `InnoRouterCore` so the
  binding API lives with the stores. Existing
  `import InnoRouterMacros` consumers are unaffected — Macros keeps
  `@_exported import InnoRouterCore`.
- Bindings route every mutation through the existing command
  pipeline so middleware and telemetry observe them exactly as with
  direct `execute(...)`.

#### P1-3 Named stack intents — **Shipped (#14)**

High-frequency intents compose from existing
`NavigationCommand` primitives with no engine changes.

Shape (landed):

- `NavigationIntent.replaceStack([R])` — composes `.replace(routes)`.
- `NavigationIntent.backOrPush(R)` — composes `.popTo(route)` with
  fallback to `.push(route)`.
- `NavigationIntent.pushUniqueRoot(R)` — dedupes when the current
  root already matches, otherwise pushes.
- `FlowIntent` parallels were intentionally skipped —
  `FlowIntent` is a higher-level abstraction with modal-step
  invariants, so low-level stack intents don't map 1:1.

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

#### P2-2 `Codable` route stacks + `FlowPlan` + state restoration

Opt-in `Codable` on `RouteStack<R>`, `RouteStep<R>`, and `FlowPlan<R>`,
plus a `StatePersistence` helper for launch-time restoration. TCA and
FlowStacks both offer this.

**Coupling**: `RouteStep` / `FlowPlan` Codable is also a prerequisite
for P0-3 deep-link path rehydration. The Codable surface should land
as a small standalone PR _before_ P0-3 so the pipeline extension can
build on stable serialisation.

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

| Priority | Item | Impact | Difficulty | Status |
|---|---|---|---|---|
| P0 | NavigationTestStore / ModalTestStore / FlowTestStore (`InnoRouterTesting`) | positioning-decisive | large | **shipped** |
| P0 | Unified FlowStack (push + sheet + cover) | positioning | medium–large | **shipped (#12 + 47467b50)** |
| P0 | Deep link path rehydration + `FlowPlan` pipeline | deep-link selling point | medium | open |
| P1 | Coordinator composition (`ChildCoordinator` + `push(child:)`) | coordinator UX | medium | **shipped (#14)** |
| P1 | Typed destination bindings (`binding(case:)`) | ergonomics | small | **shipped (#14)** |
| P1 | Named stack intents (`replaceStack`/`backOrPush`/`pushUniqueRoot`) | ergonomics | small | **shipped (#14)** |
| P1 | ModalStore middleware | symmetry | small | **shipped (#12)** |
| P2 | Unified telemetry stream | analytics unification | small | open |
| P2 | `Codable` (`RouteStack` / `RouteStep` / `FlowPlan`) + restoration | real-app requirement | medium | open (prereq for P0-3) |
| P2 | UIKit escape hatch | adoption path | large | open |
| P2 | DocC walkthroughs | learning curve | small–medium | open |
| P3 | Macro diagnostics, algebra, plugin, PBT | polish | small | open |

## 6. Suggested next work

With P0-1 (`InnoRouterTesting`), P0-2 (FlowStack), and P1-4
(ModalStore middleware) all shipped, the remaining critical path
collapses to a single track:

- **Deep-link rehydration for flows**: land P2-2 first as a small
  Codable PR (`RouteStack`, `RouteStep`, `FlowPlan`), then P0-3 on
  top — `DeepLinkPathResolver` + `FlowDeepLinkPipeline` + wiring
  into `DeepLinkEffectHandler` so URLs can terminate on a modal step
  and rehydrate through `FlowStore.apply`. The new
  `FlowTestStore` covers regression for this work at the intent
  boundary.

**Ergonomics cluster (small, compatible, ship opportunistically)**:
P1-2 typed destination bindings + P1-3 named stack intents. Each is a
single-file PR and collectively raises the daily-use bar. Best landed
as fill-in work between the larger tracks.

**Largest remaining architectural decision**: P1-1 coordinator
composition — parent/child finish propagation touches the `Coordinator`
protocol shape. Worth a short design note before implementation so the
`FlowStore` ↔ coordinator handoff story stays consistent.

## 7. Sources

- InnoRouter repo, `main @ d1d89920` (2026-04-20).
- [pointfreeco/swift-composable-architecture](https://github.com/pointfreeco/swift-composable-architecture)
- [pointfreeco/swift-navigation](https://github.com/pointfreeco/swift-navigation)
- [johnpatrickmorgan/FlowStacks](https://github.com/johnpatrickmorgan/FlowStacks)
- [johnpatrickmorgan/TCACoordinators](https://github.com/johnpatrickmorgan/TCACoordinators)
- [rundfunk47/stinsen](https://github.com/rundfunk47/stinsen)
- [SwiftfulThinking/SwiftfulRouting](https://github.com/SwiftfulThinking/SwiftfulRouting)
- [forXifLess/LinkNavigator](https://github.com/forXifLess/LinkNavigator)
