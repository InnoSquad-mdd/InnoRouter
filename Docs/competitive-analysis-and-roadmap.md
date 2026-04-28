# Competitive Analysis and Improvement Roadmap

_Last updated: 2026-04-27 · Maintainer snapshot after the 4.0.0 unreleased quality and adoption sweep_

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
| Deep link pipeline | ✅ Matcher + Pipeline + AuthPolicy + Outcome **+ composite `FlowDeepLinkPipeline` (push + modal tail)** | ⚠ hand-hydrate | ❌ | ✅ rebuild path | ✅ | ⚠ manual | ❌ | ✅ URL-first, no modal tail |
| Public observability hooks | ✅ onChange / Batch / Transaction / MiddlewareMutation **+ unified `store.events` AsyncStream** | ✅ TestStore covers it | ⚠ `observe { }` | ❌ | ✅ | ❌ | ❌ | ❌ |
| Codable state restoration | ✅ opt-in `Codable` + `StatePersistence<R>` | ✅ `StackState: Codable` | ❌ | ✅ | ✅ | ⚠ | ❌ | ⚠ |
| Batch + Transaction split | ✅ two models | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Validator / Mismatch policy | ✅ `RouteStackValidator`, `NavigationPathMismatchPolicy` | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Host-less testing | ✅ `InnoRouterTesting` (Navigation / Modal / Flow) | ✅ **`TestStore`** | ✅ assert on model | ✅ value-typed arrays | ✅ | ❌ | ⚠ | ⚠ |
| Macros | ✅ `@Routable`, `@CasePathable` | ✅ `@Reducer`, `@Presents`, `@CasePathable` | ✅ `@CasePathable` | ❌ | (TCA) | ❌ | ❌ | ❌ |
| Swift 6 strict concurrency | ✅ **enforced per module** | ✅ | ✅ | ⚠ in progress | ⚠ | ❌ | ✅ | ✅ |
| iOS floor | **18+** | 13+ / 17+ for Observation | 13+ | 16+ | 13+ | 14+ | 17+ | 16+ |
| Cross-surface (UIKit / AppKit) | ❌ SwiftUI only (by choice) | ⚠ | ✅ **4 products** | ❌ | ⚠ | ⚠ | ❌ | ❌ |
| **All Apple platforms via SwiftUI** (iOS / iPadOS / macOS / tvOS / watchOS / visionOS) | ✅ **all 6 with per-platform CI + platform matrix docs** | ⚠ SwiftUI adopters only | ⚠ SwiftUI module only | ⚠ | ⚠ | ⚠ | ⚠ | ⚠ |
| **visionOS spatial presentations** (ornament / volumetric / immersive space) | ✅ `SceneStore` + `SceneHost` + `innoRouterOrnament` | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
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
- **Lag**: no cross-surface story (UIKit / AppKit / Linux).
  Small teams can still ship with swift-navigation + a hand-rolled router.

### vs FlowStacks — 967★
- **Lead**: typed results, middleware (on _both_ Navigation and Modal),
  pipeline, validator. FlowStacks is pure path manipulation.
- **Lag (narrowed)**: `FlowStore<R>` now exposes
  `path: [RouteStep<R>]` as a single source of truth over the internal
  `NavigationStore` + `ModalStore`, so push + sheet + cover serialise as
  one value and opt-in `Codable` state restoration now falls out of the
  same `RouteStep` / `FlowPlan` surface. Remaining lag is adoption
  simplicity, not value-level restoration coverage.

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
  exceptionally strong for deep-link rehydration. InnoRouter now
  rehydrates multi-step paths and modal-terminal URLs through a single
  typed `FlowPlan`, but LinkNavigator still has the lighter-weight
  string-path authoring story.

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

Unlocks: flow-level deep links, restoration, replay. Follow-up
work is now adoption proof (examples, case studies, and app
migrations), not missing core value semantics.

#### P0-3 Deep-link path rehydration + `FlowPlan` integration — **Shipped**

A URL can now rehydrate a push prefix plus a modal terminal step
atomically through `FlowStore.apply(_:)`. InnoRouter becomes the
only surveyed framework that covers both multi-segment paths **and**
modal-terminal URLs in a typed pipeline.

Shape (landed):

- `FlowDeepLinkMapping<R>` / `FlowDeepLinkMatcher<R>` in
  `InnoRouterDeepLink` — each handler returns a full `FlowPlan<R>`,
  so multi-segment URLs are explicit at the mapping site (no trie,
  no per-segment chaining) and modal-terminal URLs fall out
  naturally (`FlowPlan(steps: [.sheet(.privacy)])`).
- `FlowDeepLinkDecision<R>` + `FlowPendingDeepLink<R>` parallel the
  push-only `DeepLinkDecision` / `PendingDeepLink`. Kept as
  separate types so adding the flow surface didn't break
  exhaustive switches over the existing enum.
- `FlowDeepLinkPipeline<R>` composes scheme / host validation,
  the matcher, and `DeepLinkAuthenticationPolicy<R>` (reused
  verbatim from the push-only pipeline). Auth policy scans the
  plan until it reaches the first protected route.
- `FlowDeepLinkEffectHandler<R>` in `InnoRouterDeepLinkEffects`
  drives a `FlowPlanApplier<R>` — new Core protocol that
  `FlowStore` already satisfies through its `apply(_:)` method.
  Keeps the effects module out of SwiftUI's dependency graph.
- Pending-replay loop mirrors the push-only handler:
  `resumePendingDeepLink()` / async `resumePendingDeepLinkIfAllowed`
  re-consult the authentication policy when the gate probably opens.

Unlocks: composite deep links competitive with LinkNavigator (plus
modal-terminal URLs, which LinkNavigator can't express), so URL
handling + scene-phase restoration + offline replay all funnel
through a single `FlowPlan` pipeline.

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

The P3 cancellation follow-up is now closed by
`ChildCoordinator.parentDidCancel` and `ChildCoordinatorTaskTracker`.

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
  stack already contains the route, otherwise pushes.
- `FlowIntent` keeps its own higher-level surface because modal-step
  invariants still matter, but the missing ergonomic gap is now closed
  by the shipped modal-aware variants (`.backOrPushDismissingModal`,
  `.pushUniqueRootDismissingModal`) tracked later in the roadmap.

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

#### P2-1 Unified telemetry stream — **Shipped**

All observation surfaces are now reachable through a single
`AsyncStream` per store, so analytics, logging, and debugging
pipelines wire up once instead of N individual callbacks.

Shape (landed):

- `NavigationEvent<R>` / `ModalEvent<M>` / `FlowEvent<R>` public
  enums in `InnoRouterSwiftUI` mirror every existing configuration
  hook (5 / 5 / 4 cases respectively).
- `NavigationStore.events: AsyncStream<NavigationEvent<R>>`,
  `ModalStore.events`, and `FlowStore.events` broadcast every
  observation event through a shared `EventBroadcaster<Event>`
  helper. `FlowStore.events` wraps inner navigation / modal
  emissions into `.navigation(...)` / `.modal(...)` so one
  subscriber sees the full chain.
- Subscribers clean up via `AsyncStream.Continuation.onTermination`;
  store `isolated deinit` (SE-0371) finishes outstanding
  continuations so `for await` loops terminate naturally.
- Existing `onChange` / `onPresented` / `onCommandIntercepted` /
  etc. callbacks remain source-compatible — the stream is an
  additional channel, not a replacement.
- `InnoRouterTesting`'s legacy `NavigationTestEvent` /
  `ModalTestEvent` / `FlowTestEvent` types are preserved as
  `typealias`es for source compatibility.

#### P2-2 `Codable` route stacks + `FlowPlan` + state restoration — **Shipped**

Opt-in `Codable` now covers the full value-level flow surface,
with a typed `StatePersistence<R>` helper for the Data boundary.

Shape (landed):

- Conditional `Codable` conformance on `RouteStack<R>`,
  `RouteStep<R>`, and `FlowPlan<R>` — apps that don't opt their
  routes into `Codable` pay nothing.
- `StatePersistence<R: Route & Codable>` exposes
  `encode(_:) -> Data` / `decode(_:) -> FlowPlan<R>` pairs plus
  `encode(_:) -> Data` / `decodeStack(_:) -> RouteStack<R>`,
  with pluggable `JSONEncoder` / `JSONDecoder` for deterministic
  output.
- Deliberately stops at the byte boundary — file I/O,
  `UserDefaults`, iCloud, and scene-phase hooks stay app
  concerns.
- `NavigationCommand` and `NavigationPlan` remain non-Codable by
  design; they are runtime-level and have no user-facing
  restoration semantics.
- Unblocks P0-3: `FlowDeepLinkPipeline` can now carry a
  `FlowPlan<R>` across URL / `Codable` boundaries.

#### P2-3 UIKit escape hatch — **Declined for 3.0.0**

InnoRouter keeps a SwiftUI-only positioning stance for 3.0.0. A
minimal UIKit module would broaden the public surface and dilute the
store / flow / scene story at release time. Teams that need UIKit /
AppKit adapters can compose those surfaces outside InnoRouter.

#### P2-4 DocC walkthroughs — **Shipped**

Tutorial-style narrative articles now live alongside the existing
symbol reference in each module catalog.

Shape (landed):

- `InnoRouterSwiftUI.docc/Articles/Tutorial-LoginOnboarding.md` —
  `FlowStore` + `ChildCoordinator` wizard flow.
- `Tutorial-DeepLinkReconciliation.md` — `DeepLinkPipeline` +
  `PendingDeepLink` replay + events stream for analytics.
- `Tutorial-MiddlewareComposition.md` — logging / entitlement /
  analytics middleware stacks on both Nav and Modal with
  participant discipline explained.
- `Tutorial-MigratingFromNestedHosts.md` — step-by-step guide to
  replace `ModalHost { NavigationHost { ... } }` with `FlowHost`.
- `InnoRouterTesting.docc/Articles/Tutorial-TestingFlows.md` —
  host-less test harness tour with `FlowTestStore`.

### P3 — Polish / Nice to have

#### Shipped

- **P3-1 Parent Task cancellation → `ChildCoordinator.parentDidCancel`**
  — `push(child:)` now routes Task cancellation through
  `withTaskCancellationHandler`, calling a new `parentDidCancel()`
  protocol requirement on the main actor. Default implementation
  is an empty no-op so existing conformances keep building.
  Directional: `parentDidCancel` is parent → child, `onCancel`
  stays child → parent. Store-level cancellation remains an app
  concern; `parentDidCancel` is the framework's cancellation
  entry point.
- **P3-2 FlowIntent named-intent parity** — `.replaceStack([R])`
  (drops modal tail, then resets push prefix), `.backOrPush(R)`
  (pops to an existing stack route; otherwise behaves like `.push`,
  including modal-tail rejection), `.pushUniqueRoot(R)` (silent
  no-op when the stack already contains the route; otherwise
  dispatches as `.push`).
  Semantics deliberately honour the modal-tail invariant instead
  of silently blending — the variants that couldn't fit without
  changing that contract (`replaceStackPreservingModal`, etc.)
  were left as app policy.

#### Shipped (continued)

- **P3-3 Macro diagnostics** — `@Routable` and `@CasePathable`
  now share a `MacroDiagnostic` layer. Misapplication to a struct
  or class attaches a Swift FixIt offering to change the keyword
  to `enum`. Empty enums now produce an error instead of silently
  expanding to nothing.
- **P3-4 Command algebra extensions** —
  `.whenCancelled(NavigationCommand<R>, fallback:)` adds a
  synchronous fallback case to `NavigationCommand`, handled both
  by `NavigationEngine` (engine-level failures) and
  `NavigationStore` (middleware-driven cancellation).
  `ThrottleNavigationMiddleware<R, C>` adds a
  generic-over-Clock middleware for rate-limiting with
  deterministic test-clock injection. Debounce semantics shipped
  in 4.0.0 as `DebouncingNavigator`, keeping timer-driven delayed
  execution outside the synchronous `NavigationCommand` algebra.
- **P3-5 StoreObserver protocol adapter** — replaces a full
  `NavigationPlugin` surface (which would have duplicated the
  `events: AsyncStream` channel). `StoreObserver` is a thin
  protocol over the existing stream with typed `handle(_:)`
  dispatch for `NavigationEvent` / `ModalEvent` / `FlowEvent`,
  plus a `StoreObserverSubscription` token with isolated-deinit
  auto-cancellation.
- **P3-6 Property-based tests** — `NavigationPropertyBasedTests`
  uses `@Test(arguments:)` to exercise compositionality of
  `.sequence` and snapshot semantics of `.whenCancelled` across
  many seeds. The pre-existing random-command test in
  `NavigationCommandTests.swift` already used the same pattern; this
  complements it with engine-level invariants.
- **P3-7 FlowIntent modal-aware variants** —
  `.backOrPushDismissingModal(R)` and
  `.pushUniqueRootDismissingModal(R)` dismiss any active modal
  tail then dispatch through the base intent, with middleware
  cancellation propagating coherently.
- **P3-8 ChildCoordinatorTaskTracker** — opt-in helper that
  child coordinators compose into `parentDidCancel()` to cancel
  tracked async `Task`s in one call. No protocol change, so
  coordinators that don't need task tracking skip it entirely.
- **P3-9 Cross-launch pending deep links** — `FlowPendingDeepLink`
  gains conditional `Codable` conformance and a
  `FlowPendingDeepLinkPersistence<R: Route & Codable>` helper
  mirrors `StatePersistence<R>` (Data ↔ value, no I/O policy).
  `FlowDeepLinkEffectHandler.restore(pending:)` re-installs a
  decoded pending link for replay. Push-only `PendingDeepLink`
  stays non-Codable because `NavigationPlan` is runtime-only
  by design.

#### Superseded or declined

- **`.debounce` as a `NavigationCommand` case** — superseded by
  `DebouncingNavigator`. The engine remains synchronous and the
  debounce window lives in an async wrapper with `Clock` injection.
- **Full `NavigationPlugin` surface** — superseded by
  `StoreObserver` for the observability use case. A
  plugin-style lifecycle sub-framework is not currently
  justified given the `events` stream.

## 5. Summary backlog table

| Priority | Item | Impact | Difficulty | Status |
|---|---|---|---|---|
| P0 | NavigationTestStore / ModalTestStore / FlowTestStore (`InnoRouterTesting`) | positioning-decisive | large | **shipped** |
| P0 | Unified FlowStack (push + sheet + cover) | positioning | medium–large | **shipped (#12 + 47467b50)** |
| P0 | Deep link path rehydration + `FlowDeepLinkPipeline` | deep-link selling point | medium | **shipped** |
| P1 | Coordinator composition (`ChildCoordinator` + `push(child:)`) | coordinator UX | medium | **shipped (#14)** |
| P1 | Typed destination bindings (`binding(case:)`) | ergonomics | small | **shipped (#14)** |
| P1 | Named stack intents (`replaceStack`/`backOrPush`/`pushUniqueRoot`) | ergonomics | small | **shipped (#14)** |
| P1 | ModalStore middleware | symmetry | small | **shipped (#12)** |
| P2 | Unified telemetry stream (`store.events: AsyncStream`) | analytics unification | small | **shipped** |
| P2 | `Codable` (`RouteStack` / `RouteStep` / `FlowPlan`) + `StatePersistence` | real-app requirement | medium | **shipped** |
| P2 | UIKit escape hatch | adoption path | large | declined for 3.0.0 |
| P2 | DocC walkthroughs (5 tutorial articles) | learning curve | small–medium | **shipped** |
| P3 | Parent Task cancellation (`parentDidCancel`) | coordinator UX polish | small | **shipped** |
| P3 | FlowIntent named-intent parity (`.replaceStack`/`.backOrPush`/`.pushUniqueRoot`) | ergonomics parity | small | **shipped** |
| P3 | Macro diagnostics + FixIts | DX polish | small | **shipped** |
| P3 | Command algebra: `.whenCancelled` + throttling + debouncing wrapper | UX polish | small | **shipped** |
| P3 | `StoreObserver` protocol adapter | observability ergonomics | small | **shipped** |
| P3 | Property-based tests (Swift Testing `@Test(arguments:)`) | invariant coverage | small | **shipped** |
| P3 | FlowIntent modal-aware variants | ergonomics | small | **shipped** |
| P3 | `ChildCoordinatorTaskTracker` | cancellation ergonomics | small | **shipped** |
| P3 | Cross-launch pending deep links (Codable `FlowPendingDeepLink` + persistence) | state restoration | small | **shipped** |
| All-platform | All six Apple platforms via SwiftUI + visionOS spatial presentations | positioning | medium | **shipped** |

## 6. Suggested next work

With the P3 polish cluster shipped (macro FixIts, `.whenCancelled`,
`ThrottleNavigationMiddleware`, `DebouncingNavigator`,
`StoreObserver`, property-based tests, modal-aware FlowIntent
variants, `ChildCoordinatorTaskTracker`,
`FlowPendingDeepLinkPersistence`) **and the all-platform /
visionOS-spatial extension** (`ScenePresentation`, `SceneDeclaration`,
`SceneRegistry`, `SceneStore`, `SceneHost`, `innoRouterOrnament`,
per-platform CI), the P0 / P1 / P3 backlog is **empty** and
SwiftUI-only is the final positioning stance.

Current investment direction: **finish the 4.0.0 unreleased quality
and adoption sweep, refresh public examples/docs from the source
contract, then tag 4.0.0**.

- **P2-3 UIKit escape hatch** — declined. SwiftUI-only positioning
  is now explicit in the roadmap and in the README platform-support
  matrix. Teams that need UIKit / AppKit adapters can compose
  swift-navigation for those surfaces alongside InnoRouter for
  stack / modal / flow authority.
- **Macro dependency cost spike** — keep `InnoRouterMacros` in this
  package for 4.0.0. Before introducing package traits or a separate
  macro package, compare `swift package show-traits`,
  `swift build --target InnoRouter`, and
  `swift build --target InnoRouterMacros` against the migration cost
  for existing `import InnoRouterMacros` users.

## 7. Sources

- InnoRouter repo, `main @ 5808d8f` + 4.0.0 unreleased sweep (2026-04-27).
- [pointfreeco/swift-composable-architecture](https://github.com/pointfreeco/swift-composable-architecture)
- [pointfreeco/swift-navigation](https://github.com/pointfreeco/swift-navigation)
- [johnpatrickmorgan/FlowStacks](https://github.com/johnpatrickmorgan/FlowStacks)
- [johnpatrickmorgan/TCACoordinators](https://github.com/johnpatrickmorgan/TCACoordinators)
- [rundfunk47/stinsen](https://github.com/rundfunk47/stinsen)
- [SwiftfulThinking/SwiftfulRouting](https://github.com/SwiftfulThinking/SwiftfulRouting)
- [forXifLess/LinkNavigator](https://github.com/forXifLess/LinkNavigator)
