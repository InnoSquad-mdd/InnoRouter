import InnoRouterCore

public enum NavigationPathMismatchResolution<R: Route>: Sendable {
    case single(NavigationCommand<R>)
    case batch([NavigationCommand<R>])
    case ignore
}

public enum NavigationPathMismatchPolicy<R: Route>: Sendable {
    case replace
    case assertAndReplace
    case ignore
    case custom(
        @MainActor @Sendable (_ oldPath: [R], _ newPath: [R]) -> NavigationPathMismatchResolution<R>
    )
}
