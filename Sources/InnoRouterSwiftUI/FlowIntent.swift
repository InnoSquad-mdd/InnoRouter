import InnoRouterCore

/// Public intent dispatched to `FlowStore.send(_:)`.
///
/// `FlowIntent` mirrors the intent layers used by `NavigationStore` /
/// `ModalStore` but operates on the unified `FlowStore` path where navigation
/// and modal progression live in a single array of `RouteStep`s.
public enum FlowIntent<R: Route>: Sendable, Equatable {
    /// Push a route onto the navigation stack prefix of the flow.
    case push(R)
    /// Present a sheet modal as the tail of the flow.
    case presentSheet(R)
    /// Present a full-screen cover modal as the tail of the flow.
    case presentCover(R)
    /// Pop the last navigation push from the flow, if any.
    case pop
    /// Dismiss the currently active modal tail, if any.
    case dismiss
    /// Replace the flow path with the supplied steps, subject to the
    /// FlowStore invariants (at most one modal step, and only at the tail).
    case reset([RouteStep<R>])

    /// Replace the navigation push prefix with `routes` and **drop any
    /// active modal tail**.
    ///
    /// Mirrors `NavigationIntent.replaceStack([R])` on the flow surface.
    /// Because the flow's modal invariant forbids modal steps in any
    /// non-tail position, a "replace stack" operation can't preserve
    /// a modal by definition — any active modal is dismissed as part
    /// of the reset.
    ///
    /// Equivalent to `.reset(routes.map(RouteStep.push))` but
    /// communicates intent at the call site.
    case replaceStack([R])

    /// If `route` already exists in the current navigation push
    /// prefix, pop back to it. Otherwise, behave like `.push(route)`.
    ///
    /// Mirrors `NavigationIntent.backOrPush(R)`. When a modal tail is
    /// active:
    ///
    /// - `route` in nav stack: pops to it (the existing modal is
    ///   independently managed — the nav pop does not touch it, so
    ///   callers that want the modal dismissed first should
    ///   `.dismiss` explicitly).
    /// - `route` absent: rejected with `.pushBlockedByModalTail`,
    ///   matching `.push` semantics.
    case backOrPush(R)

    /// If the current navigation stack's **root** is already `route`
    /// (and the stack has exactly one push), this intent is a silent
    /// no-op. Otherwise it behaves like `.push(route)`.
    ///
    /// Mirrors `NavigationIntent.pushUniqueRoot(R)`. When a modal tail
    /// is active and the intent would otherwise push, it's rejected
    /// with `.pushBlockedByModalTail`, matching `.push` semantics.
    case pushUniqueRoot(R)
}

/// Reason surfaced to `FlowStoreConfiguration.onIntentRejected` when
/// `FlowStore` refuses to apply a user intent.
public enum FlowRejectionReason: Sendable, Equatable {
    /// A `.push` was requested while the flow tail is already a modal step.
    /// Dismiss the modal first, or use `.reset(_:)` to rewrite the stack.
    case pushBlockedByModalTail
    /// A `.reset(_:)` path violates FlowStore invariants (e.g. more than one
    /// modal step, or a modal step that is not the final element).
    case invalidResetPath
    /// A navigation or modal middleware cancelled the underlying command,
    /// so `FlowStore.path` was rolled back.
    case middlewareRejected(debugName: String?)
}
