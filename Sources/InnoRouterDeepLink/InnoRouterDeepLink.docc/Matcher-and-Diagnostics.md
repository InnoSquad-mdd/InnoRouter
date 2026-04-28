# Matcher and diagnostics

@Metadata {
  @PageKind(article)
}

`DeepLinkMatcher` and `FlowDeepLinkMatcher` are the URL-pattern front doors for deep-link routing.

## Pattern model

Patterns support:

- literal segments
- named parameters such as `:id`
- terminal wildcard `*`

This keeps matching simple and predictable for app routing.

Wildcards are terminal-only. A pattern like `/api/*/users` is invalid:
it produces a `.nonTerminalWildcard(pattern:index:)` diagnostic and does
not match runtime paths.

Captured values stay available as strings through `firstValue(forName:)`
and `values(forName:)`. For common scalar types, use the typed overloads:

```swift skip doc-fragment
let id = parameters.firstValue(forName: "id", as: UUID.self)
let page = parameters.firstValue(forName: "page", as: Int.self)
let selectedTags = parameters.values(forName: "tag", as: String.self)
```

## Match precedence

Match precedence remains declaration-order based.

That means:

- earlier patterns win
- diagnostics do not change runtime behavior
- ordering is still part of the matcher contract

## Diagnostics

`DeepLinkMatcherConfiguration` can surface diagnostics for common authoring mistakes:

- duplicate patterns
- wildcard shadowing
- non-terminal wildcards
- parameter-heavy patterns that subsume more specific later patterns

Diagnostics are available on both push-only and flow matchers. They
are intended to catch ambiguous authoring early without changing the
matcher’s runtime semantics.
