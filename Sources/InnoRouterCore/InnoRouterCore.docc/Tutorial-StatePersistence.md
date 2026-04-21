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
let plan = FlowPlan(steps: flowStore.path)
let data = try persistence.encode(plan)
try data.write(to: restorationURL, options: .atomic)

// At launch time:
if let data = try? Data(contentsOf: restorationURL) {
    let restored = try persistence.decode(data)
    flowStore.apply(restored)
}
```

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
