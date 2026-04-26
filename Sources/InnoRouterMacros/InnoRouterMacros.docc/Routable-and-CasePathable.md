# Routable and CasePathable

@Metadata {
  @PageKind(article)
}

Use macros when you want concise route declarations in user-facing code and examples.

## `@Routable`

`@Routable` removes the manual `Route` conformance declaration for route enums.

It is the preferred style for:

- README examples
- DocC snippets
- human-facing examples in `Examples/`

## `@CasePathable`

`@CasePathable` generates lightweight case-path support for enum extraction and composition.

This is useful when:

- feature code needs ergonomic enum matching
- a route hierarchy should expose reusable extraction helpers

## Examples vs smoke fixtures

The repository intentionally splits examples:

- `Examples/` uses macros and the most idiomatic API surface
- `ExamplesSmoke/` uses compiler-stable fixtures for CI

That split keeps public-facing docs modern without making CI depend on every macro edge case.

## Limitations: generic enums

Both `@Routable` and `@CasePathable` reject generic enum declarations with an
explicit compiler error:

```swift
@Routable
enum Generic<T> { case detail(T) } // ❌ error: @Routable does not support generic enum declarations
```

The generated `enum Cases` would need to materialise `CasePath<Self, T>`
members for each generic instantiation, but Swift does not propagate the
parent's generic parameters into a nested type that way. Diagnostic ID
`InnoRouterMacros.unsupportedGenericEnum` is emitted on the generic
parameter clause.

If you need a generic shape, separate the generic case into a non-generic
wrapper:

```swift
@Routable
enum AppRoute: Route {
    case home
    case detail(DetailRoute) // wrap a concrete payload type
}

// Keep the generic carrier outside the route enum.
struct DetailRoute<T>: Hashable { let payload: T }
```
