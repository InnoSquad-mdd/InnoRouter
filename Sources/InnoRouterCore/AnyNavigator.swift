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
    func push(_ route: R) {
        _ = execute(.push(route))
    }

    @discardableResult
    func pop() -> NavigationResult<R> {
        execute(.pop)
    }

    func popToRoot() {
        _ = execute(.popToRoot)
    }

    func replace(with routes: [R]) {
        _ = execute(.replace(routes))
    }
}
