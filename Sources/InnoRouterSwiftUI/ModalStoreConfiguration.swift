import OSLog

import InnoRouterCore

public enum ModalDismissalReason: Sendable, Equatable {
    case dismiss
    case dismissAll
    case systemDismiss
}

public struct ModalStoreConfiguration<M: Route>: Sendable {
    public let logger: Logger?
    public let onPresented: (@MainActor @Sendable (ModalPresentation<M>) -> Void)?
    public let onDismissed: (@MainActor @Sendable (ModalPresentation<M>, ModalDismissalReason) -> Void)?
    public let onQueueChanged: (@MainActor @Sendable ([ModalPresentation<M>], [ModalPresentation<M>]) -> Void)?

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
