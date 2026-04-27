# Intent vs Command vs Plan — Selection Guide

InnoRouter exposes four different request types. Picking the wrong
one is the most common source of "why is my flow rejected?" friction
in code reviews, so this guide names each one and points at the use
case it was designed for.

## At a glance

| Surface | Type | Use when |
|---|---|---|
| Imperative low-level | `NavigationCommand<R>` / `ModalCommand<M>` | You hold a store reference and want explicit control over a single push, pop, present, or replace. Middleware sees this. |
| SwiftUI view layer | `NavigationIntent<R>` / `ModalIntent<M>` / `FlowIntent<R>` | A view dispatches a high-level intent through `@EnvironmentNavigationIntent` / `@EnvironmentModalIntent` / `@EnvironmentFlowIntent`. The store decomposes the intent into one or more commands and runs the middleware pipeline. |
| Composite multi-step | `FlowPlan<R>` | A deep link, restoration snapshot, or pre-built scenario commits a whole push prefix + modal tail in one shot. |

## NavigationCommand vs NavigationIntent

`NavigationCommand<R>` is the lowest-level instruction the engine
understands: `.push(R)`, `.pop`, `.popTo(R)`, `.replace([R])`, etc. It
goes through `NavigationStore.execute(_:)` and `executeBatch(_:)` and
fires every middleware in the registry.

`NavigationIntent<R>` is the view-layer vocabulary: `.go(R)`,
`.back`, `.backTo(R)`, `.backOrPush(R)`, `.pushUniqueRoot(R)`,
`.replaceStack([R])`, `.resetTo([R])`. It is dispatched through the
SwiftUI environment from a child view that does not hold a store
reference. The store maps each intent to one or more commands and
runs them through the same pipeline.

Use **commands** in app-boundary code (effect handlers, deep-link
coordinators, test scaffolding) where you want exact control. Use
**intents** in views and view models so the view layer is decoupled
from store internals.

## ModalCommand vs ModalIntent

`ModalCommand<M>` is `.present(ModalPresentation<M>)`,
`.replaceCurrent(ModalPresentation<M>)`, `.dismissCurrent(reason:)`,
`.dismissAll`. `ModalIntent<M>` is the view-layer wrapper:
`.present(M, style:)`, `.dismiss`, `.dismissAll`.

The same imperative-vs-view-layer split applies. Inside a flow,
prefer `FlowIntent` over either of these — see below.

## NavigationIntent vs FlowIntent

`FlowIntent<R>` is the only intent vocabulary that can express the
"push then sheet" / "cover then dismiss while keeping push tail"
patterns that span both stores in a `FlowStore<R>`. Cases you only
get from `FlowIntent`:

- `.presentSheet(R)` / `.presentCover(R)` over the current push tail
- `.backOrPushDismissingModal(R)` — pop modal tail, then either pop
  back to an existing push or push fresh
- `.pushUniqueRootDismissingModal(R)` — same, but only push if the
  root doesn't already contain that route

If you are inside a `FlowStore`, use `FlowIntent`. Six of its eleven
cases overlap with `NavigationIntent` semantically (push, pop, reset,
replaceStack, backOrPush, pushUniqueRoot), but only `FlowIntent`
correctly accounts for the modal tail.

## When to use FlowPlan

`FlowPlan<R>` is the composite type for "land the user in *exactly*
this state." It carries an ordered list of `RouteStep<R>` values
(push / sheet / cover) and is the unit that `FlowDeepLinkPipeline`
returns. Use a `FlowPlan` when:

- A deep link rehydrates a multi-step screen flow including a modal
  tail.
- Restoration replays a saved snapshot at app launch.
- A test sets up a known starting point in one shot.

`FlowStore.apply(_:)` runs every step through the same middleware
chain that intents and commands use, so middleware decisions still
apply.

## Quick decision flowchart

```text
Are you in a SwiftUI view that doesn't hold the store?
├── Yes → use intents (NavigationIntent / ModalIntent / FlowIntent)
└── No  → are you composing a multi-step landing surface?
         ├── Yes → use FlowPlan
         └── No  → use commands (NavigationCommand / ModalCommand)
```

## Pitfalls

1. **Don't reach into `flowStore.navigationStore.execute(...)`.**
   Direct inner-store mutation bypasses FlowStore-level invariants
   such as the modal-tail block on `push` while a sheet is up. Use
   the FlowStore surface (`apply` / `send` with a `FlowIntent`) in
   flow scenarios.
2. **Don't pick `NavigationCommand.replace([])` to "reset".** An
   empty replace clears the stack but is a single command; a clear
   reset of an in-flight flow is `flowStore.send(.reset)`.
3. **Don't synthesise composite plans from `FlowIntent` chains.**
   A sequence of `.push` + `.presentSheet` runs middleware twice and
   surfaces two `.pathChanged` events; `FlowPlan` runs the same
   surface as one transactional commit with one event.
