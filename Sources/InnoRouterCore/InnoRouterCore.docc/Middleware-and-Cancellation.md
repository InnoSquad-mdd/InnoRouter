# Middleware and cancellation

@Metadata {
  @PageKind(article)
}

Middleware is the cross-cutting policy layer for navigation execution.

## Interception phase

`NavigationMiddleware.willExecute(_:state:)` runs before the engine applies a command.

It returns `NavigationInterception`:

- `.proceed(updatedCommand)`
- `.cancel(reason)`

This allows middleware to:

- rewrite commands
- block execution
- attach a typed cancellation reason

Cancellation reasons live in `NavigationCancellationReason` and stay visible in the final `NavigationResult`.

## Post-execution phase

`NavigationMiddleware.didExecute(_:result:state:)` folds the execution result after the engine runs.

This method can:

- inspect the final `RouteStack`
- transform the `NavigationResult`
- attach analytics or logging side effects

It cannot mutate router state directly. State mutation authority stays in the executor.

## Why middleware is synchronous

Core middleware is intentionally synchronous. Async policy checks belong at the app boundary rather than inside the core execution pipeline.

If an app needs async authorization, use the effect-layer guarded execution helpers instead of making core middleware re-entrant and actor-heavy.
