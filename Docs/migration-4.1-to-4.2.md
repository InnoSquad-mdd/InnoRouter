# Migrating from 4.1 to 4.2

4.2 is **additive only**. Existing call sites keep compiling
without changes. This page summarises what is *new* (so you can
opt in deliberately), what is *now experimental* (so you can
plan for it), and what to do (or not do) when bumping the
package version.

If you are reading this before deciding to bump: nothing in 4.2
removes or renames a public symbol or changes the documented
behaviour of an existing call site. Bumping is safe.

## Bumping the package version

```diff
 dependencies: [
-    .package(url: "https://github.com/InnoSquadCorp/InnoRouter.git", from: "4.1.0")
+    .package(url: "https://github.com/InnoSquadCorp/InnoRouter.git", from: "4.2.0")
 ]
```

If you adopt the experimental spatial scene surface (see below),
pin to an exact 4.x release rather than `from:` until the surface
graduates.

## What is new

### Documentation foundation

Three new entry points for adopters and contributors:

- [`Docs/StoreSelectionGuide.md`](StoreSelectionGuide.md) — start
  here when you are choosing between `NavigationStore`,
  `ModalStore`, `FlowStore`, and the experimental `SceneStore`.
- [`Docs/CI-gates.md`](CI-gates.md) — every gate run by
  `principle-gates.sh`, with the local repro command for each.
- [`Examples/README.md`](../Examples/README.md) and
  [`ExamplesSmoke/README.md`](../ExamplesSmoke/README.md) — when
  to edit which side, and the macro-free constraint on smoke
  fixtures.

### New API surface

- `NavigationExecutionResult<R>` protocol unifying the shared
  shape of `NavigationBatchResult` and `NavigationTransactionResult`.
  Use it to write a single helper over either result type:

  ```swift skip
  func recordAggregate<R>(_ result: some NavigationExecutionResult<R>) {
      analytics.track(
          name: result.isSuccess ? "nav_aggregate_ok" : "nav_aggregate_fail",
          metadata: ["steps": result.executedCommands.count]
      )
  }
  ```

  `NavigationTransactionResult` gains an `isSuccess` accessor
  that mirrors `isCommitted` to satisfy the protocol's success
  predicate.

- `NavigationStore.pathBinding(policy:)` for per-call
  `NavigationPathMismatchPolicy` override:

  ```swift skip
  // store-wide stays on .replace; this binding is .ignore.
  .navigationDestination(
      for: AppRoute.self,
      destination: ...
  )
  .onAppear { store.pathBinding(policy: .ignore).wrappedValue = nextPath }
  ```

- `ModalDismissalReason.middlewareCancelled(reasonDescription:)`
  for analytics that need to distinguish a policy-driven
  dismissal from a system swipe-to-dismiss. Producers should
  emit the new case when `ModalMiddleware` cancels the active
  presentation; consumers can opt in incrementally.

### Macro diagnostics

Every `@Routable` / `@CasePathable` rejection now leads with a
stable error code:

```
[InnoRouterMacro.E001] @Routable can only be applied to enum declarations
```

Search by the code (`E001`/`E002`/`E003`) instead of localized
prose.

### Test scaffolding

Three new test suites pin previously-implicit contracts:

- `SceneStoreVisionOSTests` (visionOS leg only) — public
  envelope of the spatial scene surface.
- `MacroPerformanceTests` — 10/50/100-case `@Routable` fixtures
  exercise the macro plugin at scale and provide a runtime
  CasePath baseline.
- `StoreRaceStressTests` — TaskGroup-driven path / event /
  multi-subscriber stress on `NavigationStore`.

### Internal hardening

- `FlowStore` reentrancy is now backed by a depth counter rather
  than a `Bool` flag. No public surface change. A release-mode
  `precondition` on counter underflow catches imbalances that
  the previous `DEBUG`-only `assert` could not.

## What became experimental

The visionOS spatial scene authority is **explicitly outside the
4.x SemVer additive guarantee** in 4.2:

- `SceneStore`, `SceneHost`, `SceneAnchor`, `ScenePresentation`,
  `SceneIntent`, `SceneEvent`, `SceneRegistry`,
  `SceneDeclaration`.

If your app already adopted these, your code keeps building. The
marker is a stability expectation, not a deprecation: pin to an
exact 4.x release if you depend on the precise current shape, or
plan to follow surface changes through 4.x minors until the
marker is removed.

## What is unchanged

- `NavigationStore`, `ModalStore`, `FlowStore` public APIs.
- `NavigationCommand`, `NavigationIntent`, `ModalIntent`,
  `FlowIntent` shapes.
- The deep-link pipeline (push-only and flow).
- Middleware contracts (`willExecute` / `didExecute` /
  `NavigationInterception` / `NavigationCancellationReason`).
- Macro behaviour (`@Routable` / `@CasePathable` expansion is
  unchanged; only the diagnostic message text now carries an
  error-code prefix).
- iOS / macOS / tvOS / watchOS / visionOS platform floors.
- Swift 6.2 package tools floor.

## Additional new surfaces (followed up in this release)

Items the original migration draft listed as "deferred" but
that ended up landing in 4.2 after all:

- **Async middleware** — `AsyncNavigationMiddleware<R>` (in
  `InnoRouterCore`) and `AsyncNavigationMiddlewareExecutor<R>`
  (in `InnoRouterSwiftUI`) provide the opt-in async middleware
  slot. The synchronous engine and `NavigationStore.execute(_:)`
  keep their existing shape; apps adopt async middleware by
  routing commands through the executor instead of the store
  directly.
- **`ModalStoreConfiguration.queueCancellationPolicy`** —
  `ModalQueueCancellationPolicy<M>` lets standalone ModalStore
  users decide what happens to `queuedPresentations` when
  middleware cancels a command. `.preserve` (default), `.dropQueued`,
  or `.custom((command, reason) -> Action)`.
- **`InnoRouterEffects` as the canonical import** — README and
  DocC now recommend `import InnoRouterEffects` for new code.
  The split products (`InnoRouterNavigationEffects`,
  `InnoRouterDeepLinkEffects`) stay available for source
  compatibility through the 4.x line and fold into the umbrella
  in a future major.
- **`NavigationStore.commands(for:)`** — exposes the
  `NavigationIntent → [NavigationCommand]` projection.
  `send(_:)` is now implemented in terms of this accessor so
  the two surfaces cannot drift. 5.0 prep for the intent ↔
  command unification.
- **`NavigationPathReconciling<R>` protocol** — observational
  in 4.2. 5.0 will hang an injectable reconciler off
  `NavigationStoreConfiguration` through this protocol.
- **`LifecycleSignals` composition type** — observational in
  4.2 (no SDK producers yet). 5.0 will route parent-cancel /
  teardown through this bag of optional callbacks across every
  coordinator type.
- **`FlowStateReading<R>` protocol** — non-SPI read-only
  projection of FlowStore-shaped state. Observational in 4.2 —
  5.0 will move adopters off `@_spi(FlowStoreInternals)` onto
  this protocol.
- **Store responsibility splits** —
  `NavigationStore.swift` shrinks from 807 → ~640 LOC by
  extracting `+Intent`, `+Binding`, `+Middleware` extensions.
  `ModalStore.swift` shrinks from 879 → ~810 LOC by extracting
  `+Middleware` and `+Binding`. `FlowStore.swift` extracts the
  public `send(_:)` / `apply(_:)` wrappers into
  `FlowStore+Public.swift`. No public API change.
- **Macro plugin split** — `CasePathMemberBuilder.swift` (237
  LOC) is split into iteration / generation / builder files by
  responsibility.

## What did *not* land in 4.2

- **Full FlowStore responsibility split** — the dispatch spine
  (`dispatchPush`, `dispatchPop`, `dispatchModal`,
  `dispatchReset`, etc.), `withInternalMutation`, and the queue
  policy helper stay in the core file because pulling them out
  would require widening many private members for marginal
  benefit while the file is well under the lint warning
  threshold.
- **Protocol wiring for the 5.0 prep types** — the new
  protocols (`NavigationPathReconciling`,
  `FlowStateReading`) and `LifecycleSignals` ship as additive
  surface only. Wiring them as the canonical replacement for the
  current internals belongs in 5.0.
- **Effects product consolidation** — the umbrella
  (`InnoRouterEffects`) now is recommended in docs, but the
  split products are not source-deprecated yet. 5.0 folds the
  splits into the umbrella as the breaking step.
- **Coordinator protocol re-design** — Coordinator,
  FlowCoordinator, TabCoordinator, ChildCoordinator keep their
  current shape. 5.0 will adopt `LifecycleSignals` and
  re-pivot the responsibility graph.
