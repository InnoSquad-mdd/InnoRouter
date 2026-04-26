# State Persistence and Restoration

`StatePersistence` is a thin helper that serializes `FlowPlan` and
`RouteStack` values to `Data` for launch-time restoration. It deliberately
stops at the value boundary so apps keep full control over where — and
when — snapshots are written.

## Overview

InnoRouter models a running flow as a single value (`FlowPlan<R>` /
`RouteStack<R>`). When both the routes (`R`) and the containing types
are `Codable`, the entire state can round-trip through JSON. That is
enough for state restoration, deep-link payloads, and offline replay.

`StatePersistence<R>` bundles a `JSONEncoder` and `JSONDecoder` so
call sites don't have to redeclare them:

```swift
let persistence = StatePersistence<AppRoute>()

// At checkpoint time (e.g. scene will deactivate):
let plan = try FlowPlan(validating: flowStore.path)
let data = try persistence.encode(plan)
try data.write(to: restorationURL, options: .atomic)

// At launch time:
if let data = try? Data(contentsOf: restorationURL) {
    let restored = try persistence.decode(data)
    flowStore.apply(restored)
}
```

## Validation on decode

A `FlowPlan` always satisfies the FlowStore invariants:

- At most one modal step.
- A modal step only at the tail of `steps`.
- All other steps are `.push`.

`FlowPlan(validating:)` and `FlowPlan.validate(_:)` enforce these
invariants up front and throw `FlowPlanValidationError` on
violation. Codable decode runs the same validator and converts a
violation into `DecodingError.dataCorruptedError`, so a
`FlowPlan` round-tripped through disk or network can no longer
silently produce a value that `apply(_:)` will reject later. If
the snapshot format on disk drifts (older builds, hand-edited
JSON, schema migration mid-flight), the decode call surfaces the
error at restoration time — not at the next user action.

The permissive `FlowPlan(steps:)` initializer remains available
for internal builders that already trust the origin of `steps`.

## Scope

The helper intentionally covers only the typed `Data ↔ value` bridge.
Out of scope, by design:

- Where the encoded bytes live (`UserDefaults`, a file URL, iCloud,
  a database) — that is app policy.
- When snapshots are taken — tie the call into `ScenePhase`,
  `UIScene` lifecycle, or a custom trigger.
- Version-aware migration from older snapshot formats — add a
  wrapper struct around `FlowPlan` if the underlying routes evolve.
- Selective field redaction — encode only the fragments the app is
  willing to persist.

## Customising the encoder

Any `JSONEncoder` and `JSONDecoder` are acceptable inputs. Pass a
preconfigured pair to the initializer for deterministic output, date
strategies, or custom key coding:

```swift
let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys, .prettyPrinted]

let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601

let persistence = StatePersistence<AppRoute>(encoder: encoder, decoder: decoder)
```

## Error surface

Both `encode(_:)` and `decode(_:)` re-throw the underlying
`EncodingError` / `DecodingError` so call sites keep the diagnostic
context needed to distinguish schema drift from I/O failures.
