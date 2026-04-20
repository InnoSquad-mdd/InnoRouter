/// A single modal state mutation routed through the middleware pipeline.
///
/// `ModalCommand` is the modal analog of `NavigationCommand`. All `ModalStore`
/// public mutations (`present(_:style:)`, `dismissCurrent()`, `dismissAll()`)
/// funnel through a single `execute(_:)` path so that `ModalMiddleware` can
/// intercept, rewrite, or cancel them uniformly.
public enum ModalCommand<M: Route>: Sendable, Equatable {
    /// Request to present `presentation`. When a modal is already active the
    /// presentation may be queued (the queue is an application-level detail
    /// and is resolved after interception).
    case present(ModalPresentation<M>)

    /// Dismiss the currently active presentation with the provided reason.
    case dismissCurrent(reason: ModalDismissalReason)

    /// Dismiss all presentations (current + queue).
    case dismissAll
}
