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

@MainActor
public struct AnyNavigationMiddleware<R: Route>: NavigationMiddleware, Sendable {
    public typealias RouteType = R

    private let _willExecute: @MainActor @Sendable (NavigationCommand<R>, RouteStack<R>) -> NavigationInterception<R>
    private let _didExecute: @MainActor @Sendable (NavigationCommand<R>, NavigationResult<R>, RouteStack<R>) -> NavigationResult<R>

    public init<M: NavigationMiddleware>(_ middleware: M) where M.RouteType == R {
        self._willExecute = { command, state in middleware.willExecute(command, state: state) }
        self._didExecute = { command, result, state in middleware.didExecute(command, result: result, state: state) }
    }

    public init(
        willExecute: @escaping @MainActor @Sendable (NavigationCommand<R>, RouteStack<R>) -> NavigationInterception<R>,
        didExecute: @escaping @MainActor @Sendable (NavigationCommand<R>, NavigationResult<R>, RouteStack<R>) -> NavigationResult<R> = { _, result, _ in result }
    ) {
        self._willExecute = willExecute
        self._didExecute = didExecute
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
}
