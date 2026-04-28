# Changelog

All notable changes to InnoRouter are documented here. This project
follows [Semantic Versioning](https://semver.org/) — release tags
are bare semver (no leading `v`).

## 4.0.0 - 2026-04-28

4.0.0 is InnoRouter's first OSS release and the start of the public
SemVer compatibility line. Earlier private/internal snapshots are not
part of the OSS release history. This release opens the public surface
with typed navigation, modal, flow, scene, deep-link, macro, and
host-less testing APIs, plus the release/documentation gates needed to
keep that surface stable.

The notes below call out the initial OSS surface and the compatibility
details that matter for teams that tested pre-OSS snapshots.

### Initial OSS surface

- Typed navigation, modal, and flow stores with explicit command,
  batch, transaction, and intent execution.
- SwiftUI-first hosts across Apple platforms, including visionOS
  scene/window/volumetric/immersive routing through `SceneStore`.
- App-boundary deep-link planning through push-only and composite
  `FlowDeepLinkPipeline` APIs, with pending replay and state
  persistence helpers.
- `@Routable` / `@CasePathable` macros, `InnoRouterTesting`
  host-less test stores, tutorial-grade DocC, example smoke targets,
  and release gates for public API baselines, documentation snippets,
  platform builds, and performance smoke.

### Pre-OSS compatibility notes

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
- `@Routable` / `@CasePathable` now emit an `error`-severity
  diagnostic (was `warning`) when applied to an enum with zero
  cases. The macro produces no members on an empty enum, so the
  warning was easy to miss in noisy build logs and turned the
  macro into a silent no-op. Builds now fail at the macro site
  with "add a case or remove the macro" guidance.
- `DeepLinkMatcherDiagnosticsMode.strict` is removed. The strict
  diagnostic-promotion path was always reachable only through the
  throwing `DeepLinkMatcher.init(strict:logger:mappings:)`
  initializer; configuring `.strict` on the non-throwing
  `init(configuration:mappings:)` previously trapped at runtime
  via `preconditionFailure`. The case removal makes the misuse
  unrepresentable. `.disabled` and `.debugWarnings` remain.
- `FlowStore.navigationStore` and `FlowStore.modalStore` are now
  `@_spi(FlowStoreInternals)` instead of public API. `FlowHost`,
  focused internal tests, and examples that must compose the inner
  hosts can opt into the SPI import; app code should route through
  `FlowStore.path`, `send(_:)`, `apply(_:)`, `events`, and
  `intentDispatcher` so FlowStore invariants cannot be bypassed.
- `DeepLinkPattern` now treats `*` as terminal-only. Patterns such
  as `/api/*/users` no longer match as "wildcard from here to the
  end"; matchers surface `.nonTerminalWildcard(pattern:index:)` in
  debug / strict diagnostics so ambiguous authoring fails before
  release.
- Middleware-mutation-during-willExecute semantics: when a
  middleware calls `registry.add(_:)` / `remove(_:)` from its own
  `willExecute`, the same set of middlewares that ran `willExecute`
  receives `didExecute` (or `discardExecution`) for the same
  command — the live `entries` snapshot at intercept time is
  authoritative. Previously, mid-flight inserts could deliver a
  one-sided `didExecute` to a middleware that had not run
  `willExecute`, and removes could orphan `didExecute` for a
  middleware that did. Internal API change:
  `NavigationMiddlewareRegistry.InterceptionOutcome.participantCount`
  is now `participants: [AnyNavigationMiddleware<R>]` (mirror for
  `AnyModalMiddleware`); `NavigationExecutionJournal` and
  `ModalExecutionJournal` carry the snapshot through their
  preview / transaction / discard paths.

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
- `DebouncingNavigator<N: NavigationCommandExecutor, C: Clock>`
  closes the long-deferred `.debounce` roadmap item with a wrapping
  navigator: `debouncedExecute(_:)` schedules the latest command
  after a quiet window and cancels superseded ones. Generic over
  `Clock` for deterministic test injection.
- `DeepLinkParameterValue` and typed `DeepLinkParameters`
  accessors: `firstValue(forName:as:)` and `values(forName:as:)`
  parse captured path / query values into `String`, integer and
  floating-point numeric types, `Bool`, and `UUID`. Invalid values
  return `nil` or are skipped from the typed array, leaving the
  existing string accessors unchanged.
- `DeepLinkMatcherDiagnostic.nonTerminalWildcard(pattern:index:)`
  is emitted by both push-only and flow deep-link matchers when a
  wildcard is not the final pattern segment.
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
- `release.yml` accepts `workflow_dispatch` with `tag` and
  `prerelease` inputs so `<version>-(rc|beta).<n>` tags can be
  published as GitHub pre-releases.
- `scripts/check-docs-code-blocks.sh` requires every Swift fenced
  block in repository Markdown files (`*.md`) to declare either
  `swift compile` or `swift skip <reason>`. Compile-marked snippets
  are typechecked against the local package through a temporary
  SwiftPM target, and `principle-gates.sh` now runs the repo-wide
  check.
- `Docs/macro-dependency-cost.md`, `Examples/SampleAppExample.swift`,
  `ExamplesSmoke/SampleAppSmoke.swift`, the sequence/batch/transaction
  DocC guide, and OSS metadata files (`CONTRIBUTING.md`,
  `SECURITY.md`, `CODE_OF_CONDUCT.md`) round out adoption evidence
  and examples for the current public surface.
- `scripts/lint-source-gates.sh`,
  `scripts/check-changelog-sync.sh`, the `changelog-sync` workflow
  job, weekly Dependabot config, and platform runtime tests for tvOS /
  watchOS make release drift visible before tags are cut.
- `Docs/IntentSelectionGuide.md` names the four request types
  (`NavigationCommand` / `ModalCommand` / `*Intent` / `FlowPlan`)
  side by side with imperative-vs-view-layer guidance,
  `NavigationIntent` vs `FlowIntent` decision boundary, and three
  pitfalls that come up most often in code review. The README
  "Choosing the right surface" section gains a quick decision
  flowchart and links the guide.
- `NavigationCommand.whenCancelled` doc-comment now spells out
  the broadcaster contract: at most one `.changed` event for the
  net transition, with no leakage of intermediate states reached
  during a partially-applied primary that is later rolled back.
- `Tests/InnoRouterTests/MiddlewareParticipantSnapshotTests.swift`
  locks in the in-flight middleware add/remove invariant on both
  `NavigationMiddlewareRegistry` and `ModalMiddlewareRegistry`.
- `Tests/InnoRouterTests/WhenCancelledBroadcastTests.swift` locks
  in the `.whenCancelled` broadcaster ordering contract across
  primary success, partial-sequence rollback, middleware-cancelled
  primary, and zero-net-change paths.
- `Tests/InnoRouterTests/EventBroadcasterLeakTests.swift` smokes
  the `EventBroadcaster` subscriber lifecycle so bulk subscribe /
  cancel churn drains back to zero and concurrent subscribers
  each receive every broadcast in order.

### Changed

- `DebouncingNavigator` now logs sleep failures through a new
  `os_log` `debouncing-navigator` category before tripping
  `assertionFailure`, so Release builds leave an audit trail
  even when the trap is compiled out.
- `release.yml`, `docs-ci.yml`, and `performance-smoke.yml` now use
  the same pinned Xcode setup path as `principle-gates.yml` and
  `platforms.yml`, keeping tag validation, DocC builds, and
  performance smoke checks on the gated CI toolchain.
- `README.md` reframes the iOS 18+ / Swift 6.2 floor as the
  Sendable / strict-concurrency feature it actually buys, with
  a posture comparison against peers shipping on iOS 13+ that
  rely on `@preconcurrency` / `@unchecked Sendable`.
- `scripts/check-public-api.sh` source-level Sendable contracts
  for the three configuration structs match `public var`
  instead of `public let`, tracking the v-to-l switch.
- `swift-syntax` is now pinned with
  `.upToNextMinor(from: "603.0.1")`, matching `Package.swift` and
  `Package.resolved`. Swift 6.2 remains the package floor; the current
  host validation is clean against Swift 6.3.
- `NavigationStore`, `ModalStore`, and `FlowStore` split their
  static telemetry / path-helper helpers into sibling
  `+TelemetryAdapters.swift` / `+PathHelpers.swift` extensions so
  the primary class definitions stay focused on the `Observable`
  storage and execution surface. Public-API baseline diff = 0
  for the splits.
- `NavigationEnvironmentStorage`, `ModalEnvironmentStorage`, and
  `FlowEnvironmentStorage` setters now distinguish a benign same-owner
  environment update from a different-owner overwrite at the same
  route-type slot, surfacing duplicate host registration mistakes.
- `NavigationPathMismatchPolicy` and
  `NavigationStoreConfiguration.pathMismatchPolicy` source docs now
  spell out the default `.replace` operating stance and when to use
  `.assertAndReplace`, `.ignore`, or `.custom`.
- `EventBroadcaster.subscriberCount` is documented as an
  eventually-consistent test probe after stream cancellation because
  `AsyncStream.Continuation.onTermination` hops cleanup back to the
  main actor.

### Fixed

- `FlowStore.events` now wraps inner navigation and modal callbacks
  synchronously, so `.navigation(...)` / `.modal(...)` events cannot be
  overtaken by flow-level `.pathChanged` or `.intentRejected` events.
- `@Routable` and `@CasePathable` preserve backtick-escaped Swift
  keyword cases in generated `CasePath` members.
- `FlowStore.path` now resyncs when the inner `ModalStore` swaps its
  current presentation through `replaceCurrent(_:style:)`, including
  via typed `binding(case:style:)`.
- Middleware `participantCount` prefix-iteration corruption: see the
  pre-OSS compatibility note above. `NavigationMiddlewareRegistry` and
  `ModalMiddlewareRegistry` now operate on a frozen participants
  snapshot.
- Trace metadata hot-path: `InternalExecutionTrace.withSpan`'s
  `metadata` parameter is now `@autoclosure`, and the function
  short-circuits when no recorder is installed. `String(describing:)`
  on every command/preview argument is no longer evaluated for the
  99% of installs that do not register a `Logger` or telemetry
  recorder.
- `NavigationStore.executeBatch` and `executeTransaction` now
  `reserveCapacity(commands.count)` on their per-command result
  arrays so a 64+ command batch does not pay the doubling-grow
  reallocation cost.
- `FlowStore.withInternalMutation` carries a DEBUG-only assertion
  against reentrant invocation. The flag's "set → run → restore"
  pattern is correct only under MainActor + synchronous body
  execution; a future async path would silently misbehave at the
  reverse-sync guards. Production keeps the existing zero-cost flag
  behaviour.

### Future backlog

The following review items remain intentionally outside the 4.0 GA
surface. They are internal or low-priority follow-ups without a
promised release version:

- `MiddlewareRegistryCore` generic extraction — DRY refactor of the
  decalcomania across `NavigationMiddlewareRegistry` and
  `ModalMiddlewareRegistry`. Internal-only refactor, no API impact.
- `FlowStore.path` projection caching with invalidation token —
  amortizes per-mutation array reconstruction in deep stacks.
- `FlowStore` decomposition into `FlowDispatcher` / `FlowProjection`
  / `FlowReverseSync` — internal SRP cleanup; the public facade
  (`send` / `apply` / `events` / `intentDispatcher`) remains.
- `Package.swift` example boilerplate cleanup via SPM 5.9+ resource
  enumeration (low priority — current `exampleTarget(...)` helper
  already collapses adds to two edits).
