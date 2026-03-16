import OSLog

import InnoRouterCore

/// Describes why the active modal presentation was dismissed.
public enum ModalDismissalReason: Sendable, Equatable {
    /// Dismissed by an explicit `dismiss` intent.
    case dismiss
    /// Dismissed because the entire modal stack was cleared.
    case dismissAll
    /// Dismissed by the system, such as swipe-to-dismiss.
    case systemDismiss
}

/// Configuration for `ModalStore` observability and logging.
public struct ModalStoreConfiguration<M: Route>: Sendable {
    /// Optional logger used for modal telemetry.
    public let logger: Logger?
    /// Called whenever a presentation becomes active.
    public let onPresented: (@MainActor @Sendable (ModalPresentation<M>) -> Void)?
    /// Called whenever the active presentation is dismissed.
    public let onDismissed: (@MainActor @Sendable (ModalPresentation<M>, ModalDismissalReason) -> Void)?
    /// Called whenever the queued modal list changes.
    public let onQueueChanged: (@MainActor @Sendable ([ModalPresentation<M>], [ModalPresentation<M>]) -> Void)?

    /// Creates a modal store configuration.
    public init(
        logger: Logger? = nil,
        onPresented: (@MainActor @Sendable (ModalPresentation<M>) -> Void)? = nil,
        onDismissed: (@MainActor @Sendable (ModalPresentation<M>, ModalDismissalReason) -> Void)? = nil,
        onQueueChanged: (@MainActor @Sendable ([ModalPresentation<M>], [ModalPresentation<M>]) -> Void)? = nil
    ) {
        self.logger = logger
        self.onPresented = onPresented
        self.onDismissed = onDismissed
        self.onQueueChanged = onQueueChanged
    }
}
