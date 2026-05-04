/// Reason a modal command was cancelled by the middleware pipeline.
///
/// Mirrors `NavigationCancellationReason`. When `.middleware` is returned with
/// a `nil` debug name, the registry substitutes the cancelling middleware's
/// registered `debugName` so consumers always get a best-effort source.
public enum ModalCancellationReason<M: Route>: Sendable, Equatable {
    /// Cancelled by a middleware registration. `debugName` identifies the
    /// middleware when available; `command` is the command that was about to
    /// execute.
    case middleware(debugName: String?, command: ModalCommand<M>)
    /// Cancelled because a precondition (e.g. guard clause) failed.
    case conditionFailed
    /// Cancelled for an application-defined reason.
    case custom(String)
}

public extension ModalCancellationReason {
    var localizedDescription: String {
        switch self {
        case .middleware(let debugName, let command):
            if let debugName {
                return "Modal command was cancelled by middleware '\(debugName)' while executing \(command)."
            }
            return "Modal command was cancelled by middleware while executing \(command)."
        case .conditionFailed:
            return "Modal command was cancelled because a condition failed."
        case .custom(let reason):
            return reason
        }
    }
}

/// The decision a middleware returns from `willExecute`.
public enum ModalInterception<M: Route>: Sendable, Equatable {
    /// Allow the command (potentially rewritten) to continue down the
    /// pipeline.
    case proceed(ModalCommand<M>)
    /// Cancel the command; downstream middleware will not observe it and the
    /// store will not apply any state mutation.
    case cancel(ModalCancellationReason<M>)
}
