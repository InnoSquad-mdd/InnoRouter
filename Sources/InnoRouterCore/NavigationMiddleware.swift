@MainActor
public protocol NavigationMiddleware {
    associatedtype RouteType: Route

    func willExecute(_ command: NavigationCommand<RouteType>, state: RouteStack<RouteType>) -> NavigationInterception<RouteType>
    func didExecute(
        _ command: NavigationCommand<RouteType>,
        result: NavigationResult<RouteType>,
        state: RouteStack<RouteType>
    ) -> NavigationResult<RouteType>
}

@_spi(NavigationStoreInternals)
@MainActor
public protocol AnyNavigationMiddlewareDiscardCleanupBox {
    func discardExecutionBoxed(
        command: Any,
        result: Any,
        state: Any
    )
}

@_spi(NavigationStoreInternals)
@MainActor
public protocol NavigationMiddlewareDiscardCleanup: AnyNavigationMiddlewareDiscardCleanupBox {
    associatedtype RouteType: Route

    func discardExecution(
        _ command: NavigationCommand<RouteType>,
        result: NavigationResult<RouteType>,
        state: RouteStack<RouteType>
    )
}

@_spi(NavigationStoreInternals)
public extension NavigationMiddlewareDiscardCleanup {
    func discardExecutionBoxed(
        command: Any,
        result: Any,
        state: Any
    ) {
        guard let command = command as? NavigationCommand<RouteType>,
              let result = result as? NavigationResult<RouteType>,
              let state = state as? RouteStack<RouteType> else { return }
        discardExecution(command, result: result, state: state)
    }
}

@MainActor
public struct AnyNavigationMiddleware<R: Route>: NavigationMiddleware, Sendable {
    public typealias RouteType = R

    private let _willExecute: @MainActor @Sendable (NavigationCommand<R>, RouteStack<R>) -> NavigationInterception<R>
    private let _didExecute: @MainActor @Sendable (NavigationCommand<R>, NavigationResult<R>, RouteStack<R>) -> NavigationResult<R>
    private let _discardExecution: @MainActor @Sendable (NavigationCommand<R>, NavigationResult<R>, RouteStack<R>) -> Void

    public init<M: NavigationMiddleware>(_ middleware: M) where M.RouteType == R {
        self._willExecute = { command, state in middleware.willExecute(command, state: state) }
        self._didExecute = { command, result, state in middleware.didExecute(command, result: result, state: state) }
        if let cleanupMiddleware = middleware as? any AnyNavigationMiddlewareDiscardCleanupBox {
            self._discardExecution = { command, result, state in
                cleanupMiddleware.discardExecutionBoxed(
                    command: command,
                    result: result,
                    state: state
                )
            }
        } else {
            self._discardExecution = { _, _, _ in }
        }
    }

    public init(
        willExecute: @escaping @MainActor @Sendable (NavigationCommand<R>, RouteStack<R>) -> NavigationInterception<R>,
        didExecute: @escaping @MainActor @Sendable (NavigationCommand<R>, NavigationResult<R>, RouteStack<R>) -> NavigationResult<R> = { _, result, _ in result }
    ) {
        self._willExecute = willExecute
        self._didExecute = didExecute
        self._discardExecution = { _, _, _ in }
    }

    public func willExecute(_ command: NavigationCommand<R>, state: RouteStack<R>) -> NavigationInterception<R> {
        _willExecute(command, state)
    }

    public func didExecute(
        _ command: NavigationCommand<R>,
        result: NavigationResult<R>,
        state: RouteStack<R>
    ) -> NavigationResult<R> {
        _didExecute(command, result, state)
    }

    @_spi(NavigationStoreInternals)
    public func discardExecution(
        _ command: NavigationCommand<R>,
        result: NavigationResult<R>,
        state: RouteStack<R>
    ) {
        _discardExecution(command, result, state)
    }
}
