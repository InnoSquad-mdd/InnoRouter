import InnoRouterCore

/// Resolves a SwiftUI path mismatch into executable navigation work.
public enum NavigationPathMismatchResolution<R: Route>: Sendable {
    /// Resolve the mismatch with a single command.
    case single(NavigationCommand<R>)
    /// Resolve the mismatch with a batch of commands.
    case batch([NavigationCommand<R>])
    /// Ignore the mismatch and keep the current stack unchanged.
    case ignore
}

/// Controls how `NavigationStore` handles non-prefix SwiftUI path rewrites.
public enum NavigationPathMismatchPolicy<R: Route>: Sendable {
    /// Replace the stack with the new path.
    case replace
    /// Trigger a debug assertion before replacing the stack.
    case assertAndReplace
    /// Ignore the path rewrite.
    case ignore
    /// Resolve the rewrite with custom logic.
    case custom(
        @MainActor @Sendable (_ oldPath: [R], _ newPath: [R]) -> NavigationPathMismatchResolution<R>
    )
}
