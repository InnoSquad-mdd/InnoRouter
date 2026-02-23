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

public typealias Navigator = NavigationStateReader & NavigationCommandExecutor
