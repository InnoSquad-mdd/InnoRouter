import OSLog

import InnoRouterCore

public struct NavigationMiddlewareRegistration<R: Route>: Sendable {
    public let middleware: AnyNavigationMiddleware<R>
    public let debugName: String?

    public init(
        middleware: AnyNavigationMiddleware<R>,
        debugName: String? = nil
    ) {
        self.middleware = middleware
        self.debugName = debugName
    }
}

public struct NavigationMiddlewareMetadata: Equatable, Sendable {
    public let handle: NavigationMiddlewareHandle
    public let debugName: String?

    public init(
        handle: NavigationMiddlewareHandle,
        debugName: String? = nil
    ) {
        self.handle = handle
        self.debugName = debugName
    }
}

public struct NavigationStoreConfiguration<R: Route>: Sendable {
    public let engine: NavigationEngine<R>
    public let middlewares: [NavigationMiddlewareRegistration<R>]
    public let routeStackValidator: RouteStackValidator<R>
    public let pathMismatchPolicy: NavigationPathMismatchPolicy<R>
    public let logger: Logger?
    public let onChange: (@MainActor @Sendable (RouteStack<R>, RouteStack<R>) -> Void)?
    public let onBatchExecuted: (@MainActor @Sendable (NavigationBatchResult<R>) -> Void)?
    public let onTransactionExecuted: (@MainActor @Sendable (NavigationTransactionResult<R>) -> Void)?

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
