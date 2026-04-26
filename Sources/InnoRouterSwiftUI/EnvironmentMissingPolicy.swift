import OSLog
import SwiftUI

/// Controls how InnoRouter property wrappers respond when the
/// matching `NavigationHost` / `CoordinatorHost` / `ModalHost` /
/// `FlowHost` environment is not in scope.
///
/// The default is ``crash`` so production builds catch missing
/// environment wiring early, exactly as before this option existed.
/// SwiftUI Previews, snapshot tests, and other host-less rendering
/// paths can override the default through the
/// ``SwiftUI/View/innoRouterEnvironmentMissingPolicy(_:)`` modifier
/// to keep rendering instead of trapping.
///
/// `logAndDegrade` substitutes a no-op dispatcher and emits a
/// `Logger.error` line so the missing wiring is still visible in
/// the console without aborting the process.
public enum EnvironmentMissingPolicy: Sendable, Hashable {
    /// Trap with `preconditionFailure` when the environment is
    /// missing. Default behaviour.
    case crash
    /// Log an error and return a no-op dispatcher / placeholder so
    /// the surrounding view tree can keep rendering. Intended for
    /// SwiftUI Previews, host-less snapshot tests, and similar
    /// out-of-app contexts.
    case logAndDegrade
}

extension EnvironmentValues {
    /// The `EnvironmentMissingPolicy` applied to InnoRouter's
    /// `@Environment*Intent` property wrappers within the current
    /// view tree.
    @Entry public var innoRouterEnvironmentMissingPolicy: EnvironmentMissingPolicy = .crash
}

extension View {
    /// Override the policy InnoRouter property wrappers apply when
    /// their matching host is missing from the environment.
    ///
    /// ```swift
    /// #Preview {
    ///     SomeFeatureView()
    ///         .innoRouterEnvironmentMissingPolicy(.logAndDegrade)
    /// }
    /// ```
    @MainActor
    public func innoRouterEnvironmentMissingPolicy(
        _ policy: EnvironmentMissingPolicy
    ) -> some View {
        environment(\.innoRouterEnvironmentMissingPolicy, policy)
    }
}

// MARK: - Internal helpers

@MainActor
let environmentMissingLogger = Logger(
    subsystem: "io.innosquad.innorouter",
    category: "environment-missing"
)

@MainActor
func handleMissingEnvironment(
    policy: EnvironmentMissingPolicy,
    message: () -> String
) -> Never? {
    switch policy {
    case .crash:
        preconditionFailure(message())
    case .logAndDegrade:
        let resolved = message()
        environmentMissingLogger.error("\(resolved, privacy: .public)")
        return nil
    }
}
