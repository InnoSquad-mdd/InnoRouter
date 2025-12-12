@MainActor
public protocol NavMiddleware: Sendable {
    associatedtype RouteType: Route

    func willExecute(_ command: NavCommand<RouteType>, state: NavStack<RouteType>) -> NavCommand<RouteType>?
    func didExecute(_ command: NavCommand<RouteType>, result: NavResult<RouteType>, state: NavStack<RouteType>)
}

@MainActor
public struct AnyNavMiddleware<R: Route>: NavMiddleware, Sendable {
    public typealias RouteType = R

    private let _willExecute: @MainActor @Sendable (NavCommand<R>, NavStack<R>) -> NavCommand<R>?
    private let _didExecute: @MainActor @Sendable (NavCommand<R>, NavResult<R>, NavStack<R>) -> Void

    public init<M: NavMiddleware>(_ middleware: M) where M.RouteType == R {
        self._willExecute = { command, state in middleware.willExecute(command, state: state) }
        self._didExecute = { command, result, state in middleware.didExecute(command, result: result, state: state) }
    }

    public init(
        willExecute: @escaping @MainActor @Sendable (NavCommand<R>, NavStack<R>) -> NavCommand<R>?,
        didExecute: @escaping @MainActor @Sendable (NavCommand<R>, NavResult<R>, NavStack<R>) -> Void = { _, _, _ in }
    ) {
        self._willExecute = willExecute
        self._didExecute = didExecute
    }

    public func willExecute(_ command: NavCommand<R>, state: NavStack<R>) -> NavCommand<R>? {
        _willExecute(command, state)
    }

    public func didExecute(_ command: NavCommand<R>, result: NavResult<R>, state: NavStack<R>) {
        _didExecute(command, result, state)
    }
}
