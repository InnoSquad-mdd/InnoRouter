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
