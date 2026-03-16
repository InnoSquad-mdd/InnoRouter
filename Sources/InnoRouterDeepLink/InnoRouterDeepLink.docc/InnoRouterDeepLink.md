# ``InnoRouterDeepLink``

Pattern matching, pipeline planning, and pending deep-link handling for InnoRouter.

## Overview

`InnoRouterDeepLink` turns URLs into typed routes and then into explicit navigation plans.

This module owns:

- ``DeepLinkMatcher``
- ``DeepLinkPattern``
- ``DeepLinkMatcherConfiguration``
- ``DeepLinkPipeline``
- ``DeepLinkDecision``
- ``PendingDeepLink``
- ``NavigationPlan``

The key idea is that deep links are not executed ad hoc. They are matched, validated, authorized, and planned first.

## Topics

### Essentials

- <doc:Matcher-and-Diagnostics>
- <doc:Pipeline-and-Pending-Deep-Links>

### Key Types

- ``DeepLinkMatcher``
- ``DeepLinkMatcherConfiguration``
- ``DeepLinkPattern``
- ``DeepLinkPipeline``
- ``DeepLinkDecision``
- ``PendingDeepLink``
- ``NavigationPlan``
