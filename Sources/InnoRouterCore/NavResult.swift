public enum NavResult<R: Route>: Sendable, Equatable {
    case success
    case cancelled
    case routeNotFound(R)
    case conditionNotMet
    case stackEmpty
    case multiple([NavResult<R>])

    public var isSuccess: Bool {
        switch self {
        case .success: true
        case .multiple(let results): results.allSatisfy(\.isSuccess)
        default: false
        }
    }
}

