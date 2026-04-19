import OSLog

import InnoRouterCore

/// Registers a modal middleware for `ModalStore` initialization.
public struct ModalMiddlewareRegistration<M: Route>: Sendable {
    /// Middleware instance to register.
    public let middleware: AnyModalMiddleware<M>
    /// Optional debug label used in telemetry and diagnostics.
    public let debugName: String?

    /// Creates a middleware registration.
    public init(
        middleware: AnyModalMiddleware<M>,
        debugName: String? = nil
    ) {
        self.middleware = middleware
        self.debugName = debugName
    }
}

/// Debug metadata for a registered modal middleware.
public struct ModalMiddlewareMetadata: Equatable, Sendable {
    /// Stable handle used for future mutation operations.
    public let handle: ModalMiddlewareHandle
    /// Optional debug label associated with the middleware.
    public let debugName: String?

    /// Creates middleware metadata.
    public init(
        handle: ModalMiddlewareHandle,
        debugName: String? = nil
    ) {
        self.handle = handle
        self.debugName = debugName
    }
}

/// Outcome of a `ModalStore.execute(_:)` call surfaced to `onCommandIntercepted`
/// and returned from the public execute API.
public enum ModalExecutionResult<M: Route>: Sendable, Equatable {
    /// The command executed and mutated store state. `command` is the
    /// post-interception command (possibly rewritten by middleware).
    case executed(ModalCommand<M>)
    /// `.present` admitted but another modal is already active; the
    /// presentation was appended to the queue.
    case queued(ModalPresentation<M>)
    /// Middleware cancelled the command.
    case cancelled(ModalCancellationReason<M>)
    /// The command was a no-op (e.g. `.dismissCurrent` with no active modal).
    case noop
}

/// Configuration for `ModalStore` observability, middleware, and logging.
public struct ModalStoreConfiguration<M: Route>: Sendable {
    /// Optional logger used for modal telemetry.
    public let logger: Logger?
    /// Initial middleware registrations applied at store construction time.
    public let middlewares: [ModalMiddlewareRegistration<M>]
    /// Called whenever a presentation becomes active.
    public let onPresented: (@MainActor @Sendable (ModalPresentation<M>) -> Void)?
    /// Called whenever the active presentation is dismissed.
    public let onDismissed: (@MainActor @Sendable (ModalPresentation<M>, ModalDismissalReason) -> Void)?
    /// Called whenever the queued modal list changes.
    public let onQueueChanged: (@MainActor @Sendable ([ModalPresentation<M>], [ModalPresentation<M>]) -> Void)?
    /// Called after a successful middleware mutation
    /// (`add`/`insert`/`remove`/`replace`/`move`).
    ///
    /// Invalid mutations (e.g. `replaceMiddleware(...)` with an unknown
    /// handle) never fire this callback.
    public let onMiddlewareMutation: (@MainActor @Sendable (ModalMiddlewareMutationEvent<M>) -> Void)?
    /// Called after every `execute(_:)` call, including cancelled and no-op
    /// outcomes. Use this to feed analytics or diagnostics pipelines without
    /// reaching for `@testable import`.
    public let onCommandIntercepted: (@MainActor @Sendable (ModalCommand<M>, ModalExecutionResult<M>) -> Void)?

    /// Creates a modal store configuration.
    public init(
        logger: Logger? = nil,
        middlewares: [ModalMiddlewareRegistration<M>] = [],
        onPresented: (@MainActor @Sendable (ModalPresentation<M>) -> Void)? = nil,
        onDismissed: (@MainActor @Sendable (ModalPresentation<M>, ModalDismissalReason) -> Void)? = nil,
        onQueueChanged: (@MainActor @Sendable ([ModalPresentation<M>], [ModalPresentation<M>]) -> Void)? = nil,
        onMiddlewareMutation: (@MainActor @Sendable (ModalMiddlewareMutationEvent<M>) -> Void)? = nil,
        onCommandIntercepted: (@MainActor @Sendable (ModalCommand<M>, ModalExecutionResult<M>) -> Void)? = nil
    ) {
        self.logger = logger
        self.middlewares = middlewares
        self.onPresented = onPresented
        self.onDismissed = onDismissed
        self.onQueueChanged = onQueueChanged
        self.onMiddlewareMutation = onMiddlewareMutation
        self.onCommandIntercepted = onCommandIntercepted
    }
}
