# Matcher and diagnostics

@Metadata {
  @PageKind(article)
}

`DeepLinkMatcher` is the URL-pattern front door for deep-link routing.

## Pattern model

Patterns support:

- literal segments
- named parameters such as `:id`
- terminal wildcard `*`

This keeps matching simple and predictable for app routing.

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
- parameter-heavy patterns that subsume more specific later patterns

Diagnostics are intended to catch ambiguous authoring early without changing the matcher’s runtime semantics.
