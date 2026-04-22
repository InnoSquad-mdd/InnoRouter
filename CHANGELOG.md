# Changelog

All notable changes to InnoRouter are documented here. This project
follows [Semantic Versioning](https://semver.org/) — release tags
are bare semver (no leading `v`).

## 3.0.0 (unreleased)

The 3.0.0 release closes the design phase of the framework. All
P0 / P1 / P3 backlog items are shipped; P0 / P1 / P3 surface is
stable; only P2-3 UIKit escape hatch remains open behind a
product-level SwiftUI-only vs cross-surface decision.

### Added — All Apple platforms via SwiftUI

- **visionOS 2** added as a supported platform floor, alongside the
  existing iOS 18 / iPadOS 18 / macOS 15 / tvOS 18 / watchOS 11.
- **Platform-specific SwiftUI hosts audited** with `// MARK: -
  Platform:` annotations on every `#if os(...)` gate so the
  cross-platform contract is explicit in code.
- **visionOS spatial presentations** land as a first-class API:
  - `ScenePresentation<R>` (`.window`, `.volumetric`, `.immersive`),
    `ImmersiveStyle`, `VolumetricSize`, and `OrnamentAnchor` in
    `InnoRouterCore` — SwiftUI-free, `Codable` where `R: Codable`.
  - `SceneDeclaration<R>`, `SceneRegistry<R>`, `SceneStore<R>`, and
    the `SceneHost<R>` and `SceneAnchor<R>` view modifiers
    (`.innoRouterSceneHost(_:scenes:)`,
    `.innoRouterSceneAnchor(_:scenes:attachedTo:)`) in
    `InnoRouterSwiftUI`, with both gated `#if os(visionOS)`.
    `SceneHost` is the single command dispatcher that drives
    SwiftUI's `@Environment(\.openWindow)`, `.openImmersiveSpace`,
    `.dismissImmersiveSpace`, `.dismissWindow` through an
    intent-queue handoff identical to `NavigationStore` /
    `NavigationHost`, while `SceneAnchor` silently reconciles each
    scene root's appear/disappear lifecycle back into the store's
    inventory. Volumetric size / immersive style are validated
    against shared scene declarations before dispatch.
  - `SceneEvent<R>` (`.presented`, `.dismissed`, `.rejected`)
    streamed through `SceneStore.events: AsyncStream`.
  - `.innoRouterOrnament(_:content:)` cross-platform view modifier.
    On visionOS it forwards to `ornament(attachmentAnchor:
    contentAlignment:ornament:)`. Elsewhere it is a no-op so call
    sites stay platform-neutral.
- **Per-platform CI matrix** (`.github/workflows/platforms.yml`)
  builds `InnoRouterCore`, `InnoRouterDeepLink`, and
  `InnoRouterSwiftUI` on all six platforms per PR with the latest
  stable Xcode toolchain. The authoritative correctness gate remains
  `principle-gates`; the matrix is compile-only by design.
  `scripts/principle-gates.sh` gains a matching `--platforms=`
  probe for local use.
- **New examples** `Examples/MultiPlatformExample.swift` and
  `Examples/VisionOSImmersiveExample.swift`, plus matching smoke
  targets.
- **New tutorial article**
  `Tutorial-VisionOSScenes.md` walks through `SceneStore` /
  `SceneHost` / `SceneAnchor` / `innoRouterOrnament`.

### Changed / Breaking

- **watchOS public surface no longer exposes
  `NavigationSplitHost` or `CoordinatorSplitHost`**. SwiftUI's
  `NavigationSplitView` is unavailable on watchOS, and previously
  these hosts compiled only because CI did not build for watchOS.
  watchOS apps should fall back to `NavigationHost` /
  `CoordinatorHost` in the `#else` branch of a `#if !os(watchOS)`
  check. All other platforms are unaffected.
- **visionOS scene handles are now instance-aware on the unreleased
  scene surface**:
  - `ScenePresentation<R>` cases carry stable `UUID` instance ids.
  - `SceneStore.openWindow(_:)` / `openVolumetric(_:,size:)` now
    return the created `ScenePresentation<R>` handle, and
    `SceneStore.dismissWindow(_:)` now dismisses that handle rather
    than a bare route.
  - `SceneStore.activeScenes` exposes the full recency-ordered scene
    inventory, while `currentScene` remains the summary of the most
    recent active scene.
  - `SceneAnchor` adds an `instanceID` overload for window and
    volumetric scenes, intended for value-based
    `WindowGroup(id:for:defaultValue:)` declarations.

### Added — Core authorities

- **FlowStore** unifies push + sheet + cover progression as a
  single `[RouteStep<R>]` path owning inner `NavigationStore` +
  `ModalStore`. `FlowIntent` / `FlowPlan` are the public entry
  points, with explicit invariant enforcement
  (`pushBlockedByModalTail`, `invalidResetPath`,
  `middlewareRejected`).
- **FlowHost** composes `ModalHost` over `NavigationHost` and
  wires an `AnyFlowIntentDispatcher` through the environment.
- **ModalStore middleware** parity with `NavigationStore` —
  `ModalMiddleware`, `AnyModalMiddleware`, per-command
  `willExecute` / `didExecute` interception, middleware CRUD,
  `onMiddlewareMutation`, `onCommandIntercepted`.

### Added — Testing surface

- **`InnoRouterTesting`** product ships host-less
  `NavigationTestStore` / `ModalTestStore` / `FlowTestStore`
  with Swift-Testing-native assertion helpers, strict exhaustivity,
  and a shared `TestEventQueue`. No `@testable import` required.
- Property-based tests (`@Test(arguments:)`) exercise
  `.sequence` compositionality and `.whenCancelled` snapshot
  semantics across many seeds.

### Added — Coordinator composition

- **`ChildCoordinator`** protocol with
  `parent.push(child:) -> Task<Result?, Never>` for inline
  `await` on child flow results.
- **Parent Task cancellation propagation** —
  `ChildCoordinator.parentDidCancel()` fires when the parent Task
  is cancelled, so transient child state can tear down cleanly.
- **`ChildCoordinatorTaskTracker`** opt-in helper composes into
  `parentDidCancel()` to cancel tracked async Tasks in one call.

### Added — Intents

- `NavigationIntent.replaceStack([R])` / `.backOrPush(R)` /
  `.pushUniqueRoot(R)` — named intents composed from existing
  commands.
- `FlowIntent.replaceStack([R])` / `.backOrPush(R)` /
  `.pushUniqueRoot(R)` — flow-level equivalents honouring the
  modal-tail invariant.
- `FlowIntent.backOrPushDismissingModal(R)` /
  `.pushUniqueRootDismissingModal(R)` — modal-aware variants
  that dismiss any active tail modal before dispatching.

### Added — Deep links

- **Composite `FlowDeepLinkPipeline`** — `FlowDeepLinkMatcher`,
  `FlowDeepLinkMapping`, `FlowDeepLinkDecision`,
  `FlowDeepLinkEffectHandler`. A single URL can rehydrate a push
  prefix + optional modal terminal step atomically through
  `FlowStore.apply(_:)`.
- **Cross-launch pending replay** — `FlowPendingDeepLink` is
  conditionally `Codable`; `FlowPendingDeepLinkPersistence<R>`
  bridges to `Data`; `FlowDeepLinkEffectHandler.restore(pending:)`
  re-installs a decoded pending link.

### Added — Command algebra

- **`.whenCancelled(primary, fallback:)`** — synchronous
  NavigationCommand case that falls back on any non-success
  primary outcome (engine-level failure or middleware
  cancellation). Snapshot-and-rollback guarantees no leaked
  state.
- **`ThrottleNavigationMiddleware<R, C>`** — Clock-generic
  middleware that cancels commands within a minimum interval of
  a previously accepted key. Deterministic test-clock injection
  via `TestClock` pattern.

### Added — Observation

- **`events: AsyncStream<Event>`** on every store covering the
  complete observation surface (`NavigationEvent<R>`,
  `ModalEvent<M>`, `FlowEvent<R>`). Multicasts to multiple
  subscribers via `EventBroadcaster`.
- **`StoreObserver`** protocol adapter — typed
  `handle(_:)` dispatch over the `events` stream with
  `StoreObserverSubscription` cancellation handles.
- **`NavigationStoreConfiguration.onPathMismatch`** public
  callback completes the public observation hook set.

### Added — Persistence

- Opt-in `Codable` on `RouteStack<R>`, `RouteStep<R>`,
  `FlowPlan<R>`, and `FlowPendingDeepLink<R>` when the
  underlying route is `Codable`.
- **`StatePersistence<R>`** — typed Data-boundary helper for
  `FlowPlan` / `RouteStack`.
- **`FlowPendingDeepLinkPersistence<R>`** — same shape for
  pending deep links.

### Added — Macros

- **FixIt-enabled diagnostics** on `@Routable` and
  `@CasePathable` when misapplied to `struct` / `class` — Swift
  offers a one-click change to `enum`. Empty enums produce a
  warning instead of silently expanding.

### Added — Documentation

- Seven tutorial articles across the DocC catalogs covering
  login onboarding, deep-link reconciliation, composite
  `FlowDeepLinkPipeline`, middleware composition, host
  migration, throttling, and `StoreObserver` usage.

### Breaking changes

None beyond opt-in conformances. Every change is additive to the
public surface.

### Remaining for future releases

- `.debounce` NavigationCommand — needs Clock + Task
  infrastructure outside the synchronous engine contract.
- UIKit escape hatch — awaiting product decision on
  SwiftUI-only vs cross-surface positioning.
