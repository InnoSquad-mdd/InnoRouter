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
///
/// All stored properties are `public var` so call sites can build a
/// configuration with the desired engine / middlewares once and then
/// adjust individual callbacks (`onChange`, `onPathMismatch`, …)
/// without re-stating every other parameter:
///
/// ```swift
/// var config = NavigationStoreConfiguration<AppRoute>(
///     engine: customEngine
/// )
/// config.onChange = { _, _ in analytics.send(.navChanged) }
/// config.onPathMismatch = { event in diagnostics.record(event) }
/// let store = NavigationStore(configuration: config)
/// ```
///
/// The struct stays `Sendable`; mutating an instance does not affect
/// any `NavigationStore` already constructed from a previous copy.
public struct NavigationStoreConfiguration<R: Route>: Sendable {
    /// Engine used to apply navigation commands.
    public var engine: NavigationEngine<R>
    /// Initial middleware registrations.
    public var middlewares: [NavigationMiddlewareRegistration<R>]
    /// Validator used for externally supplied route stack snapshots.
    public var routeStackValidator: RouteStackValidator<R>
    /// Policy used when a SwiftUI path update cannot be reconciled structurally.
    ///
    /// Defaults to ``NavigationPathMismatchPolicy/replace``, which treats the
    /// SwiftUI binding as the source of truth for non-prefix rewrites while
    /// still emitting `onPathMismatch` / `events` telemetry. Debug builds that
    /// want to catch every unexpected rewrite can opt into
    /// ``NavigationPathMismatchPolicy/assertAndReplace`` without changing the
    /// production default.
    public var pathMismatchPolicy: NavigationPathMismatchPolicy<R>
    /// Optional logger used for runtime telemetry.
    public var logger: Logger?
    /// Called after a state mutation changes the stack.
    public var onChange: (@MainActor @Sendable (RouteStack<R>, RouteStack<R>) -> Void)?
    /// Called after a batch execution completes.
    public var onBatchExecuted: (@MainActor @Sendable (NavigationBatchResult<R>) -> Void)?
    /// Called after a transaction execution commits or rolls back.
    public var onTransactionExecuted: (@MainActor @Sendable (NavigationTransactionResult<R>) -> Void)?
    /// Called after a successful middleware mutation (`add`/`insert`/`remove`/`replace`/`move`).
    ///
    /// Invalid mutations — for example, `replaceMiddleware(...)` with an unknown
    /// handle — never fire this callback. Use this to surface registry churn to
    /// analytics or diagnostic pipelines without reaching for `@testable import`.
    public var onMiddlewareMutation: (@MainActor @Sendable (MiddlewareMutationEvent<R>) -> Void)?
    /// Called whenever the configured `pathMismatchPolicy` resolves a path
    /// reconciliation divergence (e.g. SwiftUI swipe-back races, non-prefix
    /// path replacements). Successful prefix reductions do not fire this
    /// callback; only policy-driven resolutions do.
    ///
    /// Use this to surface path-binding instability to analytics or diagnostics
    /// without reaching for `@testable import`. Test harnesses such as
    /// `NavigationTestStore` subscribe to this hook internally to assert path
    /// mismatch handling.
    public var onPathMismatch: (@MainActor @Sendable (NavigationPathMismatchEvent<R>) -> Void)?
    /// Backpressure policy applied to each subscriber of ``NavigationStore/events``.
    ///
    /// Defaults to ``EventBufferingPolicy/default`` (``EventBufferingPolicy/bufferingNewest(_:)``
    /// with a 1024-event ceiling). Opt into ``EventBufferingPolicy/unbounded`` when a
    /// deterministic test harness needs every emitted event.
    public var eventBufferingPolicy: EventBufferingPolicy

    /// Creates a navigation store configuration.
    public init(
        engine: NavigationEngine<R> = .init(),
        middlewares: [NavigationMiddlewareRegistration<R>] = [],
        routeStackValidator: RouteStackValidator<R> = .permissive,
        pathMismatchPolicy: NavigationPathMismatchPolicy<R> = .replace,
        logger: Logger? = nil,
        onChange: (@MainActor @Sendable (RouteStack<R>, RouteStack<R>) -> Void)? = nil,
        onBatchExecuted: (@MainActor @Sendable (NavigationBatchResult<R>) -> Void)? = nil,
        onTransactionExecuted: (@MainActor @Sendable (NavigationTransactionResult<R>) -> Void)? = nil,
        onMiddlewareMutation: (@MainActor @Sendable (MiddlewareMutationEvent<R>) -> Void)? = nil,
        onPathMismatch: (@MainActor @Sendable (NavigationPathMismatchEvent<R>) -> Void)? = nil,
        eventBufferingPolicy: EventBufferingPolicy = .default
    ) {
        self.engine = engine
        self.middlewares = middlewares
        self.routeStackValidator = routeStackValidator
        self.pathMismatchPolicy = pathMismatchPolicy
        self.logger = logger
        self.onChange = onChange
        self.onBatchExecuted = onBatchExecuted
        self.onTransactionExecuted = onTransactionExecuted
        self.onMiddlewareMutation = onMiddlewareMutation
        self.onPathMismatch = onPathMismatch
        self.eventBufferingPolicy = eventBufferingPolicy
    }
}
