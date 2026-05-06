# InnoRouterDeepLinkEffects

Deep-link execution helpers layered on the navigation effect boundary.

> Recommended import: `InnoRouterEffects`. As of 4.2.0, new code
> should `import InnoRouterEffects` (the umbrella module) instead
> of `import InnoRouterDeepLinkEffects`. The split product stays
> available for source compatibility through the 4.x line — a
> future major release folds it into the umbrella.

## Overview

`InnoRouterDeepLinkEffects` combines the deep-link planning model with execution helpers.

This module is where app-boundary code can:

- execute a deep-link plan
- receive typed effect outcomes
- resume pending deep links after authentication succeeds

## Topics

### Essentials

- <doc:Deep-Link-Effect-Handling>
