# Pipeline and pending deep links

@Metadata {
  @PageKind(article)
}

`DeepLinkPipeline` is where URL acceptance and app policy meet.

## Pipeline stages

A pipeline can:

- reject a URL when configured input limits are exceeded
- reject a URL by scheme or host
- leave it unhandled
- resolve it into a route
- require authentication
- convert the route into a `NavigationPlan`

## Pending deep links

When authentication is required but not currently satisfied, the pipeline returns `DeepLinkDecision.pending(_:)`.

This is deliberate:

- the route that triggered authentication deferral is preserved
- the navigation plan is preserved
- replay responsibility remains explicit at the app boundary

That keeps auth transitions and navigation transitions separate instead of blending them into one hidden side effect.

## Planning

The planner converts a route into the exact command list that should run after acceptance. This makes deep-link execution deterministic and testable.

Authentication checks the routes referenced by the produced
`NavigationPlan`, including nested sequences and fallback commands.
If a custom planner returns no route-bearing commands, the pipeline
falls back to the originally resolved route.

Effect handlers and coordinator bridges validate a produced
`NavigationPlan` against the current `RouteStack` before executing it.
Plans that are obviously impossible, such as `.pop` on an empty stack,
surface as typed application rejections instead of partially running.
