# Command, batch, and transaction semantics

@Metadata {
  @PageKind(article)
}

InnoRouter exposes three different execution semantics on purpose.

## Single-command execution

``NavigationCommand`` models one navigation transition or a recursive command composition.

Important cases:

- `.push`
- `.pushAll`
- `.pop`
- `.popCount`
- `.popToRoot`
- `.popTo`
- `.replace`
- `.sequence`

``NavigationEngine`` executes these commands against a `RouteStack`.

## Sequence semantics

`.sequence` is command algebra, not a transaction.

That means:

- commands execute left-to-right
- earlier successful steps stay applied even if a later step fails
- the final result is ``NavigationResult/multiple(_:)``

Use `.sequence` when partial success is acceptable and the command stream itself is the point.

## Batch semantics

``NavigationBatchExecutor/executeBatch(_:stopOnFailure:)`` is for observation batching.

Batch execution still runs commands one step at a time, but it lets higher layers coalesce observation:

- step middleware still runs
- the store can emit one aggregated callback
- the caller gets a structured ``NavigationBatchResult``

Use batch execution when the caller wants one “transition event” while still preserving per-step execution.

## Transaction semantics

``NavigationTransactionExecutor/executeTransaction(_:)`` is the atomic option.

Transactions:

- preview commands on a shadow stack
- abort on the first failure or cancellation
- leave the real state unchanged on failure
- commit the final state all at once on success

Use transactions when all-or-nothing semantics are required.

## Typed failures

Core legality failures stay in typed results instead of exceptions:

- ``NavigationResult/emptyStack``
- ``NavigationResult/invalidPopCount(_:)``
- ``NavigationResult/insufficientStackDepth(requested:available:)``
- ``NavigationResult/routeNotFound(_:)``
- ``NavigationResult/cancelled(_:)``

This keeps navigation failure in normal control flow and makes policy handling easy to pattern-match.
