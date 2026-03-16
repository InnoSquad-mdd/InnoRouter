@MainActor
public protocol NavigationStateReader: AnyObject {
    associatedtype RouteType: Route
    var state: RouteStack<RouteType> { get }
}

@MainActor
public protocol NavigationCommandExecutor: AnyObject {
    associatedtype RouteType: Route
    @discardableResult
    func execute(_ command: NavigationCommand<RouteType>) -> NavigationResult<RouteType>
}

@MainActor
public protocol NavigationBatchExecutor: AnyObject {
    associatedtype RouteType: Route

    @discardableResult
    func executeBatch(
        _ commands: [NavigationCommand<RouteType>],
        stopOnFailure: Bool
    ) -> NavigationBatchResult<RouteType>
}

@MainActor
public protocol NavigationTransactionExecutor: AnyObject {
    associatedtype RouteType: Route

    @discardableResult
    func executeTransaction(
        _ commands: [NavigationCommand<RouteType>]
    ) -> NavigationTransactionResult<RouteType>
}

public typealias Navigator = NavigationStateReader & NavigationCommandExecutor
