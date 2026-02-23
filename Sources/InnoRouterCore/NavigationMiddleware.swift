@MainActor
public protocol NavigationMiddleware: Sendable {
    associatedtype RouteType: Route

    func willExecute(_ command: NavigationCommand<RouteType>, state: RouteStack<RouteType>) -> NavigationCommand<RouteType>?
    func didExecute(_ command: NavigationCommand<RouteType>, result: NavigationResult<RouteType>, state: RouteStack<RouteType>)
}

@MainActor
public struct AnyNavigationMiddleware<R: Route>: NavigationMiddleware, Sendable {
    public typealias RouteType = R

    private let _willExecute: @MainActor @Sendable (NavigationCommand<R>, RouteStack<R>) -> NavigationCommand<R>?
    private let _didExecute: @MainActor @Sendable (NavigationCommand<R>, NavigationResult<R>, RouteStack<R>) -> Void

    public init<M: NavigationMiddleware>(_ middleware: M) where M.RouteType == R {
        self._willExecute = { command, state in middleware.willExecute(command, state: state) }
        self._didExecute = { command, result, state in middleware.didExecute(command, result: result, state: state) }
    }

    public init(
        willExecute: @escaping @MainActor @Sendable (NavigationCommand<R>, RouteStack<R>) -> NavigationCommand<R>?,
        didExecute: @escaping @MainActor @Sendable (NavigationCommand<R>, NavigationResult<R>, RouteStack<R>) -> Void = { _, _, _ in }
    ) {
        self._willExecute = willExecute
        self._didExecute = didExecute
    }

    public func willExecute(_ command: NavigationCommand<R>, state: RouteStack<R>) -> NavigationCommand<R>? {
        _willExecute(command, state)
    }

    public func didExecute(_ command: NavigationCommand<R>, result: NavigationResult<R>, state: RouteStack<R>) {
        _didExecute(command, result, state)
    }
}
