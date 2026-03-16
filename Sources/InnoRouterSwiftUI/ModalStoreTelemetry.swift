import InnoRouterCore

enum ModalStoreTelemetryEvent<M: Route>: Equatable {
    case presented(ModalPresentation<M>)
    case dismissed(ModalPresentation<M>, reason: ModalDismissalReason)
    case queued(ModalPresentation<M>)
    case queueChanged(oldQueue: [ModalPresentation<M>], newQueue: [ModalPresentation<M>])
}

typealias ModalStoreTelemetryRecorder<M: Route> =
    @MainActor @Sendable (ModalStoreTelemetryEvent<M>) -> Void
