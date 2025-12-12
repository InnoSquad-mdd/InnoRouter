@MainActor
public final class AnyNavigator<R: Route>: Navigator, @unchecked Sendable {
    public typealias RouteType = R

    private let _getState: @MainActor () -> NavStack<R>
    private let _execute: @MainActor (NavCommand<R>) -> NavResult<R>

    public var state: NavStack<R> { _getState() }

    public init<N: Navigator>(_ navigator: N) where N.RouteType == R {
        self._getState = { navigator.state }
        self._execute = { navigator.execute($0) }
    }

    @discardableResult
    public func execute(_ command: NavCommand<R>) -> NavResult<R> {
        _execute(command)
    }
}

public extension AnyNavigator {
    func push(_ route: R) {
        _ = execute(.push(route))
    }

    @discardableResult
    func pop() -> NavResult<R> {
        execute(.pop)
    }

    func popToRoot() {
        _ = execute(.popToRoot)
    }

    func replace(with routes: [R]) {
        _ = execute(.replace(routes))
    }
}
