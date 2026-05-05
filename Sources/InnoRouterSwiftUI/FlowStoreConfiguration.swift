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
    /// Structured telemetry sink used for flow-level and wrapped inner-store events.
    public var telemetrySink: AnyFlowTelemetrySink<R>?
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

    /// Policy applied to ``ModalStore/queuedPresentations`` when a
    /// `NavigationStore` middleware cancels a flow-level command.
    ///
    /// Defaults to ``QueueCoalescePolicy/preserve`` so the pre-4.0
    /// observable behaviour is unchanged. Opt into
    /// ``QueueCoalescePolicy/dropQueued`` if a cancelled navigation
    /// prefix should also dismiss any modal that was waiting behind
    /// it, or supply a ``QueueCoalescePolicy/custom(_:)`` closure
    /// to decide per intent + rejection reason.
    public var queueCoalescePolicy: QueueCoalescePolicy<R>

    /// Creates a flow store configuration.
    public init(
        navigation: NavigationStoreConfiguration<R> = .init(),
        modal: ModalStoreConfiguration<R> = .init(),
        telemetrySink: AnyFlowTelemetrySink<R>? = nil,
        onPathChanged: (@MainActor @Sendable ([RouteStep<R>], [RouteStep<R>]) -> Void)? = nil,
        onIntentRejected: (@MainActor @Sendable (FlowIntent<R>, FlowRejectionReason) -> Void)? = nil,
        eventBufferingPolicy: EventBufferingPolicy = .default,
        queueCoalescePolicy: QueueCoalescePolicy<R> = .preserve
    ) {
        self.navigation = navigation
        self.modal = modal
        self.telemetrySink = telemetrySink
        self.onPathChanged = onPathChanged
        self.onIntentRejected = onIntentRejected
        self.eventBufferingPolicy = eventBufferingPolicy
        self.queueCoalescePolicy = queueCoalescePolicy
    }
}
