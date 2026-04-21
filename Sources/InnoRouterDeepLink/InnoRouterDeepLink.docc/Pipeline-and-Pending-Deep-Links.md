# Pipeline and pending deep links

@Metadata {
  @PageKind(article)
}

`DeepLinkPipeline` is where URL acceptance and app policy meet.

## Pipeline stages

A pipeline can:

- reject a URL by scheme or host
- leave it unhandled
- resolve it into a route
- require authentication
- convert the route into a `NavigationPlan`

## Pending deep links

When authentication is required but not currently satisfied, the pipeline returns `DeepLinkDecision.pending(_:)`.

This is deliberate:

- the route is preserved
- the navigation plan is preserved
- replay responsibility remains explicit at the app boundary

That keeps auth transitions and navigation transitions separate instead of blending them into one hidden side effect.

## Planning

The planner converts a route into the exact command list that should run after acceptance. This makes deep-link execution deterministic and testable.
