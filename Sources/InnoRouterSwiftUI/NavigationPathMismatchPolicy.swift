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
///
/// A non-prefix rewrite is a path change that cannot be explained as a pure
/// append or tail-pop from the store's current stack. These usually come from
/// SwiftUI-driven binding rewrites, custom host code, or a race between system
/// dismissal and programmatic navigation.
public enum NavigationPathMismatchPolicy<R: Route>: Sendable {
    /// Replace the stack with the new path.
    ///
    /// This is the production-safe default: the SwiftUI binding is treated as
    /// the source of truth for the mismatch and the store reconciles itself to
    /// that path while still emitting a `NavigationPathMismatchEvent`.
    case replace
    /// Trigger a debug assertion before replacing the stack.
    ///
    /// Use this in debug or pre-release builds when any non-prefix rewrite is
    /// suspicious but continuing with `.replace` keeps the app recoverable.
    case assertAndReplace
    /// Ignore the path rewrite.
    ///
    /// Use this only when the store must remain the sole navigation authority
    /// and external SwiftUI path rewrites should be observed but discarded.
    case ignore
    /// Resolve the rewrite with custom logic.
    ///
    /// Use this when a host has domain-specific repair rules, for example
    /// mapping a non-prefix rewrite to a sanitised batch of commands.
    case custom(
        @MainActor @Sendable (_ oldPath: [R], _ newPath: [R]) -> NavigationPathMismatchResolution<R>
    )
}
