# InnoRouterCore

State, command, result, and execution primitives for InnoRouter.

## Overview

`InnoRouterCore` is the semantic foundation of the package. It owns:

- typed routes through `Route`
- stack snapshots through `RouteStack`
- command algebra through `NavigationCommand`
- deterministic execution through `NavigationEngine`
- typed outcomes through `NavigationResult`, `NavigationBatchResult`, and `NavigationTransactionResult`
- middleware interception through `NavigationMiddleware` and `NavigationInterception`

This module does not know about SwiftUI, deep links, or presentation hosts. It only models and executes route-stack transitions.

## Topics

### Essentials

- <doc:Route-Stack-and-Validation>
- <doc:Command-Batch-and-Transaction-Semantics>
- <doc:Middleware-and-Cancellation>
- <doc:Tutorial-StatePersistence>

### Reference

- <doc:Rejection-Reasons>
