@MainActor
public protocol NavStateReadable: AnyObject, Sendable {
    associatedtype RouteType: Route
    var state: NavStack<RouteType> { get }
}

@MainActor
public protocol NavCommandExecuting: AnyObject, Sendable {
    associatedtype RouteType: Route
    @discardableResult
    func execute(_ command: NavCommand<RouteType>) -> NavResult<RouteType>
}

public typealias Navigator = NavStateReadable & NavCommandExecuting
