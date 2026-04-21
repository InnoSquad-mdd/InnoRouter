# InnoRouterNavigationEffects

Synchronous `@MainActor` helpers for executing navigation commands at app and coordinator boundaries.

## Overview

`InnoRouterNavigationEffects` exists for callers that want a small, explicit execution façade instead of talking to a store directly.

This module is intentionally navigation-only. It does not depend on deep-link parsing.

## Topics

### Essentials

- <doc:Boundary-Execution>
- <doc:Guarded-Execution>
