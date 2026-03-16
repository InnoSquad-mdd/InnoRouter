import OSLog

import InnoRouterCore

@MainActor
final class ModalStoreTelemetrySink<M: Route> {
    private let logger: Logger?
    private let recorder: ModalStoreTelemetryRecorder<M>?

    init(
        logger: Logger?,
        recorder: ModalStoreTelemetryRecorder<M>? = nil
    ) {
        self.logger = logger
        self.recorder = recorder
    }

    func recordPresented(_ presentation: ModalPresentation<M>) {
        recorder?(.presented(presentation))

        guard let logger else { return }
        logger.notice(
            """
            modal presented \
            id=\(presentation.id.uuidString, privacy: .public) \
            route=\(String(describing: presentation.route), privacy: .public) \
            style=\(String(describing: presentation.style), privacy: .public)
            """
        )
    }

    func recordDismissed(
        _ presentation: ModalPresentation<M>,
        reason: ModalDismissalReason
    ) {
        recorder?(.dismissed(presentation, reason: reason))

        guard let logger else { return }
        logger.notice(
            """
            modal dismissed \
            id=\(presentation.id.uuidString, privacy: .public) \
            route=\(String(describing: presentation.route), privacy: .public) \
            style=\(String(describing: presentation.style), privacy: .public) \
            reason=\(String(describing: reason), privacy: .public)
            """
        )
    }

    func recordQueued(_ presentation: ModalPresentation<M>) {
        recorder?(.queued(presentation))

        guard let logger else { return }
        logger.notice(
            """
            modal queued \
            id=\(presentation.id.uuidString, privacy: .public) \
            route=\(String(describing: presentation.route), privacy: .public) \
            style=\(String(describing: presentation.style), privacy: .public)
            """
        )
    }

    func recordQueueChanged(
        oldQueue: [ModalPresentation<M>],
        newQueue: [ModalPresentation<M>]
    ) {
        recorder?(.queueChanged(oldQueue: oldQueue, newQueue: newQueue))

        guard let logger else { return }
        logger.notice(
            """
            modal queue changed \
            oldCount=\(String(oldQueue.count), privacy: .public) \
            newCount=\(String(newQueue.count), privacy: .public)
            """
        )
    }
}
