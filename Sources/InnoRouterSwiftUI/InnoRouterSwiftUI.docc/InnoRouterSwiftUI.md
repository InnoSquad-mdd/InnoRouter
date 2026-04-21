# ``InnoRouterSwiftUI``

SwiftUI hosts, stores, modal routing, coordinators, and environment intent dispatch for InnoRouter.

## Overview

`InnoRouterSwiftUI` adapts the core execution model to SwiftUI.

This module owns:

- ``NavigationStore``
- ``NavigationHost`` and ``NavigationSplitHost``
- ``CoordinatorHost`` and ``CoordinatorSplitHost``
- ``ModalStore`` and ``ModalHost``
- ``NavigationIntent`` and ``ModalIntent``
- ``EnvironmentNavigationIntent`` and ``EnvironmentModalIntent``
- ``FlowCoordinator`` and ``TabCoordinator``

The guiding rule is simple: views emit intent, stores own transition authority, and hosts bridge system UI state back into those authorities.

## Topics

### Essentials

- <doc:NavigationStore-and-Hosts>
- <doc:Split-Modal-and-Composition>
- <doc:Coordinators-and-Environment-Intent>

### Tutorials

- <doc:Tutorial-LoginOnboarding>
- <doc:Tutorial-DeepLinkReconciliation>
- <doc:Tutorial-MiddlewareComposition>
- <doc:Tutorial-MigratingFromNestedHosts>
- <doc:Tutorial-Throttling>
- <doc:Tutorial-StoreObserver>

### Key Types

- ``NavigationStore``
- ``NavigationStoreConfiguration``
- ``NavigationHost``
- ``NavigationSplitHost``
- ``Coordinator``
- ``CoordinatorHost``
- ``CoordinatorSplitHost``
- ``ModalStore``
- ``ModalStoreConfiguration``
- ``ModalHost``
- ``NavigationIntent``
- ``ModalIntent``
