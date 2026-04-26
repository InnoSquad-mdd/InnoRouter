import InnoRouterCore

/// Configuration for constructing a `FlowStore`.
///
/// A `FlowStore` owns an inner `NavigationStore` and `ModalStore`; this
/// configuration gives callers a single entry point for configuring both of
/// them (logging, middleware, per-store lifecycle observers) plus FlowStore
/// specific observation hooks for path and intent rejection.
///
/// Stored properties are `public var` so call sites can adjust
/// individual hooks after construction without re-stating every
/// other parameter — see ``NavigationStoreConfiguration`` for the
/// same pattern.
public struct FlowStoreConfiguration<R: Route>: Sendable {
    /// Configuration applied to the inner `NavigationStore`.
    public var navigation: NavigationStoreConfiguration<R>
    /// Configuration applied to the inner `ModalStore`.
    public var modal: ModalStoreConfiguration<R>
    /// Called whenever `FlowStore.path` changes, with (old, new) snapshots.
    public var onPathChanged: (@MainActor @Sendable ([RouteStep<R>], [RouteStep<R>]) -> Void)?
    /// Called whenever `FlowStore.send(_:)` refuses to apply an intent.
    public var onIntentRejected: (@MainActor @Sendable (FlowIntent<R>, FlowRejectionReason) -> Void)?
    /// Backpressure policy applied to each subscriber of ``FlowStore/events``.
    ///
    /// Controls the flow-level fan-out only; the inner `NavigationStore` and
    /// `ModalStore` carry their own policies through ``NavigationStoreConfiguration/eventBufferingPolicy``
    /// and ``ModalStoreConfiguration/eventBufferingPolicy``. Defaults to
    /// ``EventBufferingPolicy/default``.
    public var eventBufferingPolicy: EventBufferingPolicy

    /// Creates a flow store configuration.
    public init(
        navigation: NavigationStoreConfiguration<R> = .init(),
        modal: ModalStoreConfiguration<R> = .init(),
        onPathChanged: (@MainActor @Sendable ([RouteStep<R>], [RouteStep<R>]) -> Void)? = nil,
        onIntentRejected: (@MainActor @Sendable (FlowIntent<R>, FlowRejectionReason) -> Void)? = nil,
        eventBufferingPolicy: EventBufferingPolicy = .default
    ) {
        self.navigation = navigation
        self.modal = modal
        self.onPathChanged = onPathChanged
        self.onIntentRejected = onIntentRejected
        self.eventBufferingPolicy = eventBufferingPolicy
    }
}
