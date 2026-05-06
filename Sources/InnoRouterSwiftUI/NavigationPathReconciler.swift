import InnoRouterCore

/// Contract for the component that turns SwiftUI's
/// `NavigationStack(path:)` mutations into the equivalent
/// ``NavigationCommand`` invocations on the store.
///
/// `NavigationStore` ships ``NavigationPathReconciler`` as the
/// default conformance. Apps that need a domain-specific repair
/// rule on every binding-driven update can supply their own
/// conformance through
/// ``NavigationStoreConfiguration/pathReconciler``.
///
/// Custom implementations should preserve the three current
/// reduction rules:
///
/// - Prefix shrink (`newPath` is a prefix of `oldPath`) →
///   `.popCount` or `.popToRoot`.
/// - Prefix expand (`oldPath` is a prefix of `newPath`) → batched
///   `.push` for the appended suffix.
/// - Non-prefix mismatch → delegate to the supplied
///   `resolveMismatch` closure (which today routes through
///   ``NavigationPathMismatchPolicy``).
@MainActor
public protocol NavigationPathReconciling<RouteType>: Sendable {
    associatedtype RouteType: Route

    func reconcile(
        from oldPath: [RouteType],
        to newPath: [RouteType],
        resolveMismatch: @MainActor ([RouteType], [RouteType]) -> NavigationPathMismatchResolution<RouteType>,
        execute: @MainActor (NavigationCommand<RouteType>) -> Void,
        executeBatch: @MainActor ([NavigationCommand<RouteType>]) -> Void
    )
}

/// Default implementation of ``NavigationPathReconciling`` used by
/// ``NavigationStore`` when the caller does not supply a custom
/// reconciler. Public so apps can compose it as a fallback inside
/// their own conformances (e.g. domain-specific rules on top of
/// the framework rules).
public struct NavigationPathReconciler<R: Route>: NavigationPathReconciling {

    nonisolated public init() {}

    public func reconcile(
        from oldPath: [R],
        to newPath: [R],
        resolveMismatch: @MainActor ([R], [R]) -> NavigationPathMismatchResolution<R>,
        execute: @MainActor (NavigationCommand<R>) -> Void,
        executeBatch: @MainActor ([NavigationCommand<R>]) -> Void
    ) {
        guard oldPath != newPath else { return }

        let commonPrefixLength = Self.longestCommonPrefixLength(between: oldPath, and: newPath)

        if commonPrefixLength == newPath.count {
            let countToPop = oldPath.count - newPath.count
            guard countToPop > 0 else { return }
            if countToPop == oldPath.count {
                execute(.popToRoot)
            } else {
                execute(.popCount(countToPop))
            }
            return
        }

        if commonPrefixLength == oldPath.count {
            let appendedRoutes = Array(newPath.dropFirst(commonPrefixLength))
            switch appendedRoutes.count {
            case 0:
                return
            case 1:
                execute(.push(appendedRoutes[0]))
            default:
                executeBatch(appendedRoutes.map(NavigationCommand.push))
            }
            return
        }

        switch resolveMismatch(oldPath, newPath) {
        case .single(let command):
            execute(command)
        case .batch(let commands):
            executeBatch(commands)
        case .ignore:
            return
        }
    }

    private static func longestCommonPrefixLength(between lhs: [R], and rhs: [R]) -> Int {
        zip(lhs, rhs).prefix { pair in
            pair.0 == pair.1
        }.count
    }
}
