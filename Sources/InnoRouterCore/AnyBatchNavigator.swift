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
    /// Pushes a route and surfaces the engine-level outcome. Mirrors
    /// ``AnyNavigator/push(_:)`` so callers using either type-erased
    /// wrapper see the same return contract.
    @discardableResult
    func push(_ route: R) -> NavigationResult<R> {
        execute(.push(route))
    }

    /// Pops the top route. Returns `.emptyStack` when nothing could be
    /// popped instead of silently no-op'ing.
    @discardableResult
    func pop() -> NavigationResult<R> {
        execute(.pop)
    }

    /// Pops every route above the root. The engine treats this as
    /// idempotent (`.success` even on an empty stack); the result is
    /// surfaced for parity with ``AnyNavigator/popToRoot()``.
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
