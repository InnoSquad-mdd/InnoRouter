public enum NavigationCancellationReason<R: Route>: Sendable, Equatable {
    case middleware(debugName: String?, command: NavigationCommand<R>)
    case conditionFailed
    case custom(String)
}

public enum NavigationInterception<R: Route>: Sendable, Equatable {
    case proceed(NavigationCommand<R>)
    case cancel(NavigationCancellationReason<R>)
}
