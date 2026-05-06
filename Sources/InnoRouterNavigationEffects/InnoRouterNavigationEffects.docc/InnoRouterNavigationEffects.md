# InnoRouterNavigationEffects

Synchronous `@MainActor` helpers for executing navigation commands at app and coordinator boundaries.

> Recommended import: `InnoRouterEffects`. As of 4.1.0, new code
> should `import InnoRouterEffects` (the umbrella module) instead
> of `import InnoRouterNavigationEffects`. The split product
> stays available for source compatibility through the 4.x line —
> a future major release folds it into the umbrella.

## Overview

`InnoRouterNavigationEffects` exists for callers that want a small, explicit execution façade instead of talking to a store directly.

This module is intentionally navigation-only. It does not depend on deep-link parsing.

## Topics

### Essentials

- <doc:Boundary-Execution>
- <doc:Guarded-Execution>
