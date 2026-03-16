@MainActor
public final class AnyBatchNavigator<R: Route>: Navigator, NavigationBatchExecutor, NavigationTransactionExecutor {
    public typealias RouteType = R

    private let _getState: @MainActor () -> RouteStack<R>
    private let _execute: @MainActor (NavigationCommand<R>) -> NavigationResult<R>
    private let _executeBatch: @MainActor ([NavigationCommand<R>], Bool) -> NavigationBatchResult<R>
    private let _executeTransaction: @MainActor ([NavigationCommand<R>]) -> NavigationTransactionResult<R>

    public var state: RouteStack<R> { _getState() }

    public init<N: Navigator & NavigationBatchExecutor & NavigationTransactionExecutor>(_ navigator: N) where N.RouteType == R {
        self._getState = { navigator.state }
        self._execute = { navigator.execute($0) }
        self._executeBatch = { commands, stopOnFailure in
            navigator.executeBatch(commands, stopOnFailure: stopOnFailure)
        }
        self._executeTransaction = { commands in
            navigator.executeTransaction(commands)
        }
    }

    @discardableResult
    public func execute(_ command: NavigationCommand<R>) -> NavigationResult<R> {
        _execute(command)
    }

    @discardableResult
    public func executeBatch(
        _ commands: [NavigationCommand<R>],
        stopOnFailure: Bool
    ) -> NavigationBatchResult<R> {
        _executeBatch(commands, stopOnFailure)
    }

    @discardableResult
    public func executeTransaction(
        _ commands: [NavigationCommand<R>]
    ) -> NavigationTransactionResult<R> {
        _executeTransaction(commands)
    }
}

public extension AnyBatchNavigator {
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
