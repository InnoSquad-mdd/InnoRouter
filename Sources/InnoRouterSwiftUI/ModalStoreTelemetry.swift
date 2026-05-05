import InnoRouterCore

enum ModalStoreTelemetryEvent<M: Route>: Equatable {
    enum MiddlewareMutation: String, Equatable {
        case added
        case inserted
        case removed
        case replaced
        case moved
    }

    enum InterceptionOutcomeKind: String, Equatable {
        case executed
        case queued
        case cancelled
        case noop
    }

    case presented(ModalPresentation<M>)
    case dismissed(ModalPresentation<M>, reason: ModalDismissalReason)
    case replaced(old: ModalPresentation<M>, new: ModalPresentation<M>)
    case queued(ModalPresentation<M>)
    case queueChanged(oldQueue: [ModalPresentation<M>], newQueue: [ModalPresentation<M>])
    case middlewareMutation(
        action: MiddlewareMutation,
        metadata: ModalMiddlewareMetadata,
        index: Int?
    )
    case commandIntercepted(
        command: ModalCommand<M>,
        outcome: InterceptionOutcomeKind,
        cancellationReason: ModalCancellationReason<M>?
    )
}

typealias ModalStoreTelemetryRecorder<M: Route> =
    @MainActor @Sendable (ModalStoreTelemetryEvent<M>) -> Void
