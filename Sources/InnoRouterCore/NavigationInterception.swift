public enum NavigationCancellationReason<R: Route>: Sendable, Equatable {
    case middleware(debugName: String?, command: NavigationCommand<R>)
    case conditionFailed
    case custom(String)
    /// Reported when an async guard (e.g. ``NavigationEffectHandler/executeGuarded(_:prepare:)``)
    /// returns a command whose legality no longer holds against the current
    /// ``RouteStack`` — typically because another actor mutated the stack while
    /// `prepare` was suspended. The associated command is the one that failed
    /// re-validation, so callers can inspect or reschedule it.
    case staleAfterPrepare(command: NavigationCommand<R>)
}

public extension NavigationCancellationReason {
    var localizedDescription: String {
        switch self {
        case .middleware(let debugName, let command):
            if let debugName {
                return "Navigation was cancelled by middleware '\(debugName)' while executing \(command)."
            }
            return "Navigation was cancelled by middleware while executing \(command)."
        case .conditionFailed:
            return "Navigation was cancelled because a condition failed."
        case .custom(let reason):
            return reason
        case .staleAfterPrepare(let command):
            return "Navigation command became stale before execution: \(command)."
        }
    }
}

public enum NavigationInterception<R: Route>: Sendable, Equatable {
    case proceed(NavigationCommand<R>)
    case cancel(NavigationCancellationReason<R>)
}
