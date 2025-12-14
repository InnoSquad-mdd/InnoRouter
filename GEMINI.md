# InnoRouter Project

## Project Overview

InnoRouter is a SwiftUI-native navigation framework with a focus on state management, unidirectional data flow, and dependency inversion. It's designed to provide a robust and scalable solution for managing navigation in SwiftUI applications. The framework is built with Swift and utilizes the latest features from Swift 6 and SwiftUI.

The core of the framework is a `NavEngine` that applies navigation commands to a `NavStack` to produce a new state. This unidirectional flow makes the navigation logic predictable and easy to test. The framework also includes a `Coordinator` pattern for centralizing navigation logic and a `DeepLink` handling mechanism.

## Building and Running

The project is a Swift Package Manager (SPM) package.

### Dependencies

The project has one external dependency:
- `swift-syntax`: For the macros.

### Building

To build the project, run the following command:

```bash
swift build
```

### Testing

To run the tests, run the following command:

```bash
swift test
```

## Development Conventions

### Code Style

The codebase is written in a clean and modern Swift style. It uses features like `Sendable` and `@MainActor` to ensure thread safety.

### Testing

The project has a comprehensive test suite that covers the core components of the framework. The tests are written using the new `Testing` framework and are located in the `Tests` directory.

### Modules

The project is divided into several modules:

- `InnoRouter`: The main umbrella library.
- `InnoRouterCore`: The core navigation logic.
- `InnoRouterSwiftUI`: The SwiftUI integration.
- `InnoRouterDeepLink`: The deep link handling logic.
- `InnoRouterMacros`: The macros for reducing boilerplate.
- `InnoRouterEffects`: Helpers for working with side-effects.

This modular architecture allows consumers to import only the parts of the framework they need.
