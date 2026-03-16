public enum NavigationResult<R: Route>: Sendable, Equatable {
    case success
    case cancelled(NavigationCancellationReason<R>)
    case emptyStack
    case invalidPopCount(Int)
    case insufficientStackDepth(requested: Int, available: Int)
    case routeNotFound(R)
    case multiple([NavigationResult<R>])

    public var isSuccess: Bool {
        switch self {
        case .success: true
        case .multiple(let results): !results.isEmpty && results.allSatisfy(\.isSuccess)
        default: false
        }
    }
}
