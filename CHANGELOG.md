# Changelog

All notable changes to InnoRouter are documented here. This project
follows [Semantic Versioning](https://semver.org/) — release tags
are bare semver (no leading `v`).

## 4.0.0 (unreleased)

4.0.0 is a quality + adoption sweep that cleans up macro-generated
visibility, ships an opt-in queue-coalesce policy, exposes
configuration mutables, and lands two adoption-focused docs (TCA
migration + onboarding case study) plus minor observability
fixes. One BREAKING change: macro-generated CasePath members now
match the enclosing enum's access level instead of always
emitting `public`.

### BREAKING

- `@Routable` and `@CasePathable` infer the access level of every
  generated `Cases` table, `is(_:)`, `[case:]`, and case
  `static let` member from the enclosing enum. `internal` and
  `private` enums no longer leak public CasePath surface. Each
  case `static let` also receives any `@available(...)`
  attribute attached to the enum case. Mark the enclosing enum
  `public` if a consumer relies on the wider surface; an opt-in
  `@Routable(visibility: .public)` argument is on the v4.x
  roadmap. See `Articles/Guide-MacroVisibility.md` for the full
  migration matrix.

### Added

- `EnvironmentMissingPolicy.assertAndLog` is a third policy
  alongside `.crash` and `.logAndDegrade`. It traps with
  `assertionFailure` in Debug while degrading to a logged no-op
  dispatcher in Release, fitting TestFlight / pre-launch ship
  configs that need loud development signal without paging
  users on a stray missing host.
- `FlowPlan(validating:)` (throwing initializer),
  `FlowPlan.validate(_:)` (public static validator), and
  `FlowPlanValidationError` (`tooManyModals`, `modalNotAtTail`)
  let deep-link planners and state-restoration drivers surface
  invariant violations up front. `FlowPlan` Codable decode runs
  the same validator and converts violations into
  `DecodingError.dataCorruptedError`.
- `QueueCoalescePolicy<R>` enum + `FlowStoreConfiguration.queueCoalescePolicy`
  setting. When a `NavigationStore` middleware cancels a
  flow-level command, the policy decides what happens to the
  modal queue: `.preserve` (default, pre-4.0 behaviour) keeps
  the queue intact; `.dropQueued` dismisses the active modal
  and drops every queued presentation (useful for
  `replaceStack` flows); `.custom(_:)` hands control to a
  closure for per-intent decisions. See
  `Articles/Guide-QueueCoalescePolicy.md`.
- `NavigationStoreConfiguration` / `ModalStoreConfiguration` /
  `FlowStoreConfiguration` stored properties are now
  `public var` so call sites can patch individual callbacks
  after construction without re-stating every parameter.
- `FlowStore.intentDispatcher` is now exposed as a cached
  property mirroring `NavigationStore` and `ModalStore`. Hosts
  no longer allocate a fresh `AnyFlowIntentDispatcher` on every
  body evaluation.
- `Tests/InnoRouterTests/ConfigurationMutationTests.swift`
  covers the `var` patchability of all three configuration
  structs.
- `Tests/InnoRouterTests/QueueCoalescePolicyTests.swift` covers
  the three policy paths (`.preserve` / `.dropQueued` /
  `.custom`) plus the caller-side invariant exclusion.
- `Sources/InnoRouterSwiftUI/InnoRouterSwiftUI.docc/Articles/Migration-FromTCA.md`
  is a step-by-step guide for migrating navigation from TCA
  (`StackState`, `@Presents`, `NavigationStackStore`) to
  InnoRouter (`NavigationStore` + `ModalStore` + `FlowStore`),
  with side-by-side reducer and view samples.
- `Sources/InnoRouterSwiftUI/InnoRouterSwiftUI.docc/Articles/CaseStudy-OnboardingFlow.md`
  is a representative composition showing how `FlowStore` +
  `ChildCoordinator` + `FlowPlan` + middleware compose into a
  12-screen onboarding sequence with deep-link rehydration and
  entitlement gating.

### Changed

- `DebouncingNavigator` now logs sleep failures through a new
  `os_log` `debouncing-navigator` category before tripping
  `assertionFailure`, so Release builds leave an audit trail
  even when the trap is compiled out.
- `README.md` reframes the iOS 18+ / Swift 6.2 floor as the
  Sendable / strict-concurrency feature it actually buys, with
  a posture comparison against peers shipping on iOS 13+ that
  rely on `@preconcurrency` / `@unchecked Sendable`.
- `scripts/check-public-api.sh` source-level Sendable contracts
  for the three configuration structs match `public var`
  instead of `public let`, tracking the v-to-l switch.

## 3.1.0 (unreleased)

3.1.0 is an additive minor that consolidates the v3.x quality
improvement backlog: macro-generation correctness for
keyword-escaped cases, FlowStore projection sync after direct
modal replacements, release-workflow support for rc/beta
pre-releases, an evidence record of macro dependency cost, and a
P0–P3 quality-improvement sweep covering build hygiene, public
messaging, internal-API cleanup, host-less rendering escape
hatches, test coverage, DX guides, and CI parallelisation.

### Added

- `release.yml` accepts `workflow_dispatch` with `tag` and
  `prerelease` inputs so `<version>-(rc|beta).<n>` tags can be
  published as GitHub pre-releases. The pre-release path skips the
  `latest/` DocC subtree through a new `build-docc-site.sh
  --skip-latest` flag.
- `Docs/macro-dependency-cost.md` records `swift package
  show-traits` output and `swift build` measurements for
  `InnoRouter` and `InnoRouterMacros` so future macro-package
  decisions have a baseline to compare against.
- `EnvironmentMissingPolicy` (`.crash` / `.logAndDegrade`) and the
  `View.innoRouterEnvironmentMissingPolicy(_:)` modifier let
  SwiftUI Previews and snapshot test harnesses keep rendering when
  the matching `NavigationHost` / `CoordinatorHost` / `ModalHost` /
  `FlowHost` is out of scope, instead of trapping with
  `preconditionFailure`.
- `DebouncingNavigator<N: NavigationCommandExecutor, C: Clock>`
  closes the long-deferred `.debounce` roadmap item with a wrapping
  navigator: `debouncedExecute(_:)` schedules the latest command
  after a quiet window and cancels superseded ones. Generic over
  `Clock` for deterministic test injection.
- `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, plus a
  README `Adopters` section establish the OSS metadata adopters
  scan first when evaluating an unfamiliar library.
- `Examples/SampleAppExample.swift` composes the headline feature
  surface (deep-link auth gating, FlowStore push+modal projection,
  DebouncingNavigator) into one self-contained authority class.
  Matching smoke at `ExamplesSmoke/SampleAppSmoke.swift`.
- DocC tutorial articles
  `Guide-SequenceVsBatchVsTransaction` and
  `Guide-FlowCoordinatorVsFlowStore` document the decision
  matrices the symbol-level docs assumed.
- `scripts/lint-source-gates.sh` extracts the grep-based source
  lints from `principle-gates.sh` so they can run standalone or in
  parallel CI jobs.
- `scripts/check-changelog-sync.sh` enforces that any
  `Baselines/PublicAPI/*.txt` change is paired with a CHANGELOG
  entry in the same diff. Wired into a dedicated
  `changelog-sync` job in `principle-gates.yml`.
- `principle-gates.yml` gains a parallel `lint` job running the
  source-level gates in five minutes, independent of the heavier
  swift test / DocC pipeline.
- `.github/dependabot.yml` opens swift-package and
  github-actions update PRs weekly so swift-syntax bumps surface
  explicitly rather than as silent transitive bumps.
- `Tests/InnoRouterTests/RouteStackStressTests.swift`,
  `ModalStoreQueueStressTests.swift`,
  `FlowDeepLinkAsyncAuthTests.swift`,
  `SceneStorePropertyBasedTests.swift` (visionOS-gated),
  `TvOSFocusNavigationTests.swift` (tvOS-gated),
  `EnvironmentMissingPolicyTests.swift`, and
  `DebouncingNavigatorTests.swift` close gaps in the test-suite
  weakness audit (deep stacks, deep modal queues, async auth
  flows, scene invariants, focus-driven traversal, environment
  policy, debounce timing).
- `EnvironmentMissingPolicy.assertAndLog` is a third policy
  alongside `.crash` and `.logAndDegrade`. It traps with
  `assertionFailure` in Debug while degrading to a logged no-op
  dispatcher in Release, fitting TestFlight / pre-launch ship
  configs that need loud development signal without paging
  users on a stray missing host. New
  `Articles/Guide-EnvironmentMissingPolicy.md` documents when to
  pick which policy.
- `FlowPlan(validating:)` (throwing initializer),
  `FlowPlan.validate(_:)` (public static validator), and
  `FlowPlanValidationError` (`tooManyModals`, `modalNotAtTail`)
  let deep-link planners and state-restoration drivers surface
  invariant violations up front instead of relying on the
  authority-level `apply(_:)` rejection. `FlowPlan` Codable decode
  now runs the same validator and converts a violation into
  `DecodingError.dataCorruptedError`, so a `FlowPlan`
  round-tripped through disk or network can no longer silently
  produce a value `apply(_:)` will reject later.
- `ModalPresentResult.rewrittenWithoutPresentation(command:)`
  distinguishes middleware rewrites that execute a non-presentation
  command (such as `.dismissCurrent` or `.dismissAll`) from a true
  store `.noop`, preserving `.noop` as "no state changed".
- `FlowStore.intentDispatcher` matches the cached dispatcher surface
  on `NavigationStore` and `ModalStore`, so `FlowHost` no longer
  allocates a fresh `AnyFlowIntentDispatcher` on every body evaluation.
- `Tests/InnoRouterTests/FlowPlanValidationTests.swift` covers
  the validating initializer, the static validator, and Codable
  decode rejections (multi-modal payloads, modal-not-at-tail
  payloads).
- `Tests/InnoRouterTests/DuplicateDispatcherDetectionTests.swift`
  pins the pure detection rule shared by the three
  `*EnvironmentStorage` setters.

### Changed

- `swift-syntax` is now pinned `.upToNextMinor(from: "602.0.0")`.
  A 603.x bump arrives as an explicit dependency-update PR
  (paired with the new dependabot config) rather than a silent
  transitive jump.
- All `swiftSettings` entries treat warnings as errors. Verified
  clean against the Swift 6.3 host build.
- The macro plugin and CasePath core types ship with English
  docstrings throughout. A new `lint-source-gates` rule rejects
  Hangul characters in `Sources/`, `Examples/`, and
  `ExamplesSmoke/` going forward.
- `NavigationMiddleware` and
  `NavigationMiddlewareDiscardCleanup` declare their associated
  type as primary, replacing the previous `@_spi`-boxed `Any`
  cast in `AnyNavigationMiddleware.init<M>` with a constrained
  existential. The `AnyNavigationMiddlewareDiscardCleanupBox` SPI
  protocol and `discardExecutionBoxed` are removed.
- `NavigationStore`, `ModalStore`, and `FlowStore` split their
  static telemetry / path-helper helpers into sibling
  `+TelemetryAdapters.swift` / `+PathHelpers.swift` extensions so
  the primary class definitions stay focused on the `Observable`
  storage and execution surface. Public-API baseline diff = 0
  for the splits.
- `RouteStack.path` carries a DEBUG-only `didSet` invariant hook
  (`assertPathIsConsistent(oldValue:)`) so future module-internal
  invariants can attach without touching the public surface.
- `InnoRouterPerformanceSmoke` accepts an optional
  `largeMaxMilliseconds` cap per sample, catching catastrophic
  absolute-time regressions the relative ratio gate would miss.
- `principle-gates.sh` delegates source-lint gates to
  `lint-source-gates.sh`. Behaviour is unchanged; the
  encapsulation lets the sub-script run independently in CI.
- `NavigationEnvironmentStorage`, `ModalEnvironmentStorage`, and
  `FlowEnvironmentStorage` setters now distinguish a benign same-owner
  environment update from a different-owner overwrite at the same
  `(R.Type)` slot — the latter signals a sibling host registering
  against a peer's dispatcher in the same scope. The duplicate path
  traps with `assertionFailure` in Debug and emits an `os_log` error
  through a new
  `duplicate-dispatcher` category in Release. The
  "Coordinators and environment intent" article documents the
  rule and the workaround (distinct route types or scoped
  environment subtrees). Direct storage writes should be single
  registrations, or use the explicit owner registration helper.

### Fixed

- `@Routable` and `@CasePathable` now preserve backtick-escaped
  Swift keyword cases (for example a `default` or `switch` case
  wrapped in backticks) in the generated `CasePath` members. The
  previous expansion emitted unescaped identifiers and failed to
  compile.
- `FlowStore.path` now resyncs when the inner `ModalStore` swaps
  its current presentation through `replaceCurrent(_:style:)`
  (including via typed `binding(case:style:)`). Observers used to
  lag one frame behind a direct modal replacement.

## 3.0.0 (unreleased)

The 3.0.0 release closes the design phase of the framework. All
P0 / P1 / P3 backlog items are shipped; P0 / P1 / P3 surface is
stable. P2-3 UIKit escape hatch is declined for 3.0.0 so the
release keeps an explicit SwiftUI-only positioning stance.

### Stability

3.0.0 is the first public release. The 3.x line follows
[Semantic Versioning](https://semver.org/) strictly — patch
releases are bug-fix only, minor releases are additive, and any
breaking change goes to a 4.0.0 cycle. See the
[Upgrading to 3.0.0](README.md#upgrading-to-300) section in the
README and the SemVer commitment in
[`RELEASING.md`](RELEASING.md#semver-commitment) for the full
contract.

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

### Pre-release sweep — runtime stability

- **`fix(effects)`**: `executeGuarded(_:, prepare:)` now
  re-validates the (possibly rewritten) command against the
  navigator's current state after `prepare` returns. If the state
  drifted while the async `prepare` was awaiting, the command is
  rejected with `.cancelled(.staleAfterPrepare(command))` instead
  of executing against a stack it no longer matches. The same
  validation runs in
  `DeepLinkEffectHandler.resumePendingDeepLinkIfAllowed(_:)`
  before each plan command, so a pending link whose stack assumption
  expired during authentication stays deferred.
- **`feat(events)`**: `EventBufferingPolicy` (`unbounded`,
  `bufferingNewest(_:)`, `bufferingOldest(_:)`) configures the
  underlying `AsyncStream` for every `events: AsyncStream`
  publisher. The default flips from unbounded to
  `.bufferingNewest(1024)` so a slow subscriber can no longer leak
  unbounded event memory; opt back into unbounded explicitly via
  `eventBufferingPolicy: .unbounded` on each store's
  configuration.
- **`feat(macros)`**: `@Routable` and `@CasePathable` now emit a
  hard diagnostic (`innoRouter.macros.unsupported_generic_enum`)
  when applied to a generic enum, with a note explaining that
  generic parameters cannot be propagated through generated
  `CasePath` members. This replaces the previous behavior of
  silently producing uncompilable expansions.

### Pre-release sweep — API consistency

- **`refactor(core)`**: `AnyNavigator.push` / `popToRoot` /
  `replace` align with the underlying `Navigator` protocol and now
  return `@discardableResult NavigationResult<R>`. Existing
  `Void`-discarding call sites keep compiling unchanged; new code
  can branch on engine outcomes through the type-erased wrapper.
- **`fix(swiftui)`**: `AnyNavigationIntentDispatcher`,
  `AnyModalIntentDispatcher`, and `AnyFlowIntentDispatcher` now
  carry a `@Sendable` annotation on their `send` closures, so
  Swift 6's strict-concurrency checks at the SwiftUI environment
  boundary catch escapes that previously slipped through implicit
  inheritance.
- **`feat(core)`**: `NavigationResult` gains
  `isMiddlewareCancellation` / `isEngineFailure` /
  `middlewareCancellationReason` computed helpers so call sites
  branching on engine-level vs middleware-level outcomes don't
  have to pattern-match the full enum.
- **`docs(readme)`**: a new "send() vs execute() — picking the
  right entry point" table makes the four-layer execution model
  (view intent / command / batch / transaction) explicit and
  cross-links to the SwiftUI tutorial.

### Pre-release sweep — performance & correctness

- **`perf(swiftui)`**: `ModalStore.effectiveTraceRecorder` and
  per-store intent dispatchers are computed once during init
  rather than on every property access, eliminating per-send
  reallocation in hot paths.
- **`fix(deeplink)`**: `DeepLinkMatcher` now percent-decodes path
  components before matching, so a URL like
  `myapp://app/hello%20world` matches a `/hello world` pattern.
  Previously these went through unchanged and missed the matcher
  silently.
- **`refactor(swiftui)`**: `NavigationHost` and `ModalHost`
  storage ownership is documented; the dual-ownership pattern
  (host `@State` + store) is intentional but was undocumented.

### Pre-release sweep — feature opt-ins

- **`feat(deeplink)`**: `DeepLinkMatcherDiagnosticsMode.strict`
  promotes any matcher diagnostic (duplicate pattern, wildcard
  shadowing, parameter shadowing) into a thrown error at matcher
  construction time. The previous `.warning` / `.silent` modes
  remain the defaults.
- **`feat(testing)`**: `FlowTestStore` gains typed
  sub-event receivers (`receiveNavigationChanged`,
  `receiveNavigationBatch`, `receiveModalPresented`,
  `receiveModalDismissed`, …) so tests assert on a specific case
  with case-aware failure messages instead of opaque predicate
  failures. The existing predicate-based `receiveNavigation(_:)` /
  `receiveModal(_:)` overloads stay source-compatible.
- **`feat(swiftui)`**: `ModalStore.present(_:style:)` now returns
  `@discardableResult ModalPresentResult<M>` so callers can
  distinguish `.shownImmediately` from `.queuedBehind` without
  inspecting the modal queue manually.
- **`feat(macros)`**: `@Routable` / `@CasePathable` applied to a
  `protocol` or `actor` no longer offer the misleading
  struct/class→enum FixIt; instead a `Note` attached to the
  declaration keyword explains that the shape requires a manual
  refactor to an enum.

### Pre-release sweep — documentation

- **`docs(core/swiftui/umbrella)`**: expanded doc comments on
  `Route`, `CasePath`, `FlowCoordinator`, `FlowStep`,
  `TabCoordinator`, `Tab`, and the `InnoRouter` umbrella to spell
  out conformance contracts, platform availability, and the
  reasons certain modules (`InnoRouterMacros`, effect modules) are
  *not* re-exported from the umbrella.
- **`docs(deeplink)`**: `FlowDeepLinkPipeline` doc comment now
  documents the multi-step authentication semantics — auth scan
  returns the **first** protected route as `.pending`, no partial
  prefix application, full plan replayed atomically. Backed by a
  new `FlowDeepLinkPipelineMultiStepAuthTests` suite.
- **`docs(release)`**: README adds a "Upgrading to 3.0.0" section
  clarifying that 3.0.0 is the first public release (no 1.x/2.x
  migration), plus a strict 3.x SemVer commitment. RELEASING.md
  documents pre-release tag flow (`3.1.0-rc.1` etc.), the
  enumerated definition of a breaking change, and the toolchain
  pin policy.
- **`docs(readme)`**: adds a tutorial-articles index linking every
  DocC catalog walkthrough (`Tutorial-LoginOnboarding`,
  `Tutorial-DeepLinkReconciliation`,
  `Tutorial-MiddlewareComposition`,
  `Tutorial-MigratingFromNestedHosts`, `Tutorial-Throttling`,
  `Tutorial-StoreObserver`, `Tutorial-VisionOSScenes`,
  `Tutorial-FlowDeepLinkPipeline`, `Tutorial-StatePersistence`,
  `Tutorial-TestingFlows`).

### Pre-release sweep — infrastructure & CI

- **`chore(package)`**: example targets now build through
  `exampleTarget(name:source:)` / `soloSmokeTarget(name:source:)`
  helpers backed by single-source-of-truth arrays. Adding a new
  example is one append to `exampleSources` plus one
  `exampleTarget(...)` call instead of nine sibling exclude-list
  edits.
- **`ci(scripts)`**: `scripts/check-examples-parity.sh` enforces
  `Examples/` ↔ `ExamplesSmoke/` ↔ `Package.swift` parity before
  the smoke build runs in `principle-gates.sh`. Hand-edits that
  forget the manifest update fail fast with a per-violation
  report.
- **`ci`**: `principle-gates.yml` and `platforms.yml` pin
  `xcode-version: "16.2"` instead of `latest-stable` so CI runs
  are reproducible across the lifetime of a release. Bumping the
  pin is now part of the release checklist.
- **`chore(tests)`**: `Tests/InnoRouterMacrosBehaviorTests/README.md`
  documents the macOS-only platform constraint (compiler-plugin
  host requirement), and the inline disabled-test note in
  `RoutableBehaviorTests.swift` lists the upstream-fix conditions
  for re-enabling.

### Breaking changes

None beyond opt-in conformances. Every change is additive to the
public surface — the only signature change is
`ModalStore.present(_:style:)` adding a non-`Void` return value
under `@discardableResult`, which is source-compatible by design.

### Fixed

- `DeepLinkPipeline` now checks authentication against every route
  referenced by the produced `NavigationPlan`, including nested
  sequences and fallback commands, before returning `.plan`.
- `DeepLinkPattern` now appends repeated path parameter values
  instead of overwriting earlier values, matching query-parameter
  merge semantics.
- `FlowDeepLinkMatcher` now exposes the same diagnostics surface as
  `DeepLinkMatcher`.
- README, roadmap, and changelog status now agree that the UIKit
  escape hatch is declined for 3.0.0.

### Deferred and closed items

- `.debounce` NavigationCommand — needs Clock + Task
  infrastructure outside the synchronous engine contract.
- UIKit escape hatch — declined for 3.0.0; compose UIKit / AppKit
  adapters outside InnoRouter if a product needs those surfaces.
- Macro dependency split — keep `InnoRouterMacros` in this package
  for 3.0.0; measure package traits or a separate macro package with
  `swift package show-traits`, `swift build --target InnoRouter`, and
  `swift build --target InnoRouterMacros` before changing package
  topology.
