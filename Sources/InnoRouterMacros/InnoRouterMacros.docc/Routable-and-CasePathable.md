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
