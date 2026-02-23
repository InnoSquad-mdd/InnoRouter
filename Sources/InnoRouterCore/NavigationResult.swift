public enum NavigationResult<R: Route>: Sendable, Equatable {
    case success
    case cancelled
    case routeNotFound(R)
    case stackEmpty
    case multiple([NavigationResult<R>])

    public var isSuccess: Bool {
        switch self {
        case .success: true
        case .multiple(let results): !results.isEmpty && results.allSatisfy(\.isSuccess)
        default: false
        }
    }
}
