@MainActor
public final class AnyNavigator<R: Route>: Navigator {
    public typealias RouteType = R

    private let _getState: @MainActor () -> RouteStack<R>
    private let _execute: @MainActor (NavigationCommand<R>) -> NavigationResult<R>

    public var state: RouteStack<R> { _getState() }

    public init<N: Navigator>(_ navigator: N) where N.RouteType == R {
        self._getState = { navigator.state }
        self._execute = { navigator.execute($0) }
    }

    @discardableResult
    public func execute(_ command: NavigationCommand<R>) -> NavigationResult<R> {
        _execute(command)
    }
}

public extension AnyNavigator {
    /// Pushes a route. Mirrors ``AnyBatchNavigator/push(_:)`` and surfaces
    /// the engine-level outcome (e.g. `.routeNotFound`, `.cancelled`) so
    /// callers can react without re-querying ``state``.
    @discardableResult
    func push(_ route: R) -> NavigationResult<R> {
        execute(.push(route))
    }

    /// Pops the top route. The result reports `.emptyStack` when the
    /// underlying stack was already empty so callers can distinguish a
    /// no-op pop from a successful one.
    @discardableResult
    func pop() -> NavigationResult<R> {
        execute(.pop)
    }

    /// Pops every route above the root. The engine treats this as
    /// idempotent (`.success` even on an already-empty stack), so callers
    /// can rely on the result for chaining without special-casing empties.
    @discardableResult
    func popToRoot() -> NavigationResult<R> {
        execute(.popToRoot)
    }

    /// Replaces the entire stack with `routes` and reports the engine
    /// outcome (success or any validator/middleware failure).
    @discardableResult
    func replace(with routes: [R]) -> NavigationResult<R> {
        execute(.replace(routes))
    }
}
