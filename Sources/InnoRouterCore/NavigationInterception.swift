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

public enum NavigationInterception<R: Route>: Sendable, Equatable {
    case proceed(NavigationCommand<R>)
    case cancel(NavigationCancellationReason<R>)
}
