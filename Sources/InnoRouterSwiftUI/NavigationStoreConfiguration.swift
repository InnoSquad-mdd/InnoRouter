import OSLog

import InnoRouterCore

/// Registers middleware for `NavigationStore` initialization.
public struct NavigationMiddlewareRegistration<R: Route>: Sendable {
    /// Middleware instance to register.
    public let middleware: AnyNavigationMiddleware<R>
    /// Optional debug label used in telemetry and diagnostics.
    public let debugName: String?

    /// Creates a middleware registration.
    public init(
        middleware: AnyNavigationMiddleware<R>,
        debugName: String? = nil
    ) {
        self.middleware = middleware
        self.debugName = debugName
    }
}

/// Debug metadata for a registered navigation middleware.
public struct NavigationMiddlewareMetadata: Equatable, Sendable {
    /// Stable handle used for future mutation operations.
    public let handle: NavigationMiddlewareHandle
    /// Optional debug label associated with the middleware.
    public let debugName: String?

    /// Creates middleware metadata.
    public init(
        handle: NavigationMiddlewareHandle,
        debugName: String? = nil
    ) {
        self.handle = handle
        self.debugName = debugName
    }
}

/// Configuration for constructing a `NavigationStore`.
public struct NavigationStoreConfiguration<R: Route>: Sendable {
    /// Engine used to apply navigation commands.
    public let engine: NavigationEngine<R>
    /// Initial middleware registrations.
    public let middlewares: [NavigationMiddlewareRegistration<R>]
    /// Validator used for externally supplied route stack snapshots.
    public let routeStackValidator: RouteStackValidator<R>
    /// Policy used when a SwiftUI path update cannot be reconciled structurally.
    public let pathMismatchPolicy: NavigationPathMismatchPolicy<R>
    /// Optional logger used for runtime telemetry.
    public let logger: Logger?
    /// Called after a state mutation changes the stack.
    public let onChange: (@MainActor @Sendable (RouteStack<R>, RouteStack<R>) -> Void)?
    /// Called after a batch execution completes.
    public let onBatchExecuted: (@MainActor @Sendable (NavigationBatchResult<R>) -> Void)?
    /// Called after a transaction execution commits or rolls back.
    public let onTransactionExecuted: (@MainActor @Sendable (NavigationTransactionResult<R>) -> Void)?

    /// Creates a navigation store configuration.
    public init(
        engine: NavigationEngine<R> = .init(),
        middlewares: [NavigationMiddlewareRegistration<R>] = [],
        routeStackValidator: RouteStackValidator<R> = .permissive,
        pathMismatchPolicy: NavigationPathMismatchPolicy<R> = .replace,
        logger: Logger? = nil,
        onChange: (@MainActor @Sendable (RouteStack<R>, RouteStack<R>) -> Void)? = nil,
        onBatchExecuted: (@MainActor @Sendable (NavigationBatchResult<R>) -> Void)? = nil,
        onTransactionExecuted: (@MainActor @Sendable (NavigationTransactionResult<R>) -> Void)? = nil
    ) {
        self.engine = engine
        self.middlewares = middlewares
        self.routeStackValidator = routeStackValidator
        self.pathMismatchPolicy = pathMismatchPolicy
        self.logger = logger
        self.onChange = onChange
        self.onBatchExecuted = onBatchExecuted
        self.onTransactionExecuted = onTransactionExecuted
    }
}
