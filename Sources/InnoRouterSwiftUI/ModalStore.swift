import Observation
import SwiftUI

import InnoRouterCore

public enum ModalPresentationStyle: Sendable, Hashable {
    case sheet
    case fullScreenCover
}

public struct ModalPresentation<M: Route>: Identifiable, Sendable, Hashable {
    public let id: UUID
    public let route: M
    public let style: ModalPresentationStyle

    public init(
        id: UUID = UUID(),
        route: M,
        style: ModalPresentationStyle
    ) {
        self.id = id
        self.route = route
        self.style = style
    }
}

public enum ModalIntent<M: Route>: Sendable, Equatable {
    case present(M, style: ModalPresentationStyle)
    case dismiss
    case dismissAll
}

@Observable
@MainActor
public final class ModalStore<M: Route> {
    public private(set) var currentPresentation: ModalPresentation<M>?
    public private(set) var queuedPresentations: [ModalPresentation<M>] = []
    private let onPresented: (@MainActor @Sendable (ModalPresentation<M>) -> Void)?
    private let onDismissed: (@MainActor @Sendable (ModalPresentation<M>, ModalDismissalReason) -> Void)?
    private let onQueueChanged: (@MainActor @Sendable ([ModalPresentation<M>], [ModalPresentation<M>]) -> Void)?
    private let telemetrySink: ModalStoreTelemetrySink<M>

    public init(
        currentPresentation: ModalPresentation<M>? = nil,
        queuedPresentations: [ModalPresentation<M>] = [],
        configuration: ModalStoreConfiguration<M> = .init()
    ) {
        let normalizedState = Self.normalize(
            currentPresentation: currentPresentation,
            queuedPresentations: queuedPresentations
        )
        let telemetrySink = ModalStoreTelemetrySink<M>(logger: configuration.logger)
        self.currentPresentation = normalizedState.current
        self.queuedPresentations = normalizedState.queue
        self.onPresented = configuration.onPresented
        self.onDismissed = configuration.onDismissed
        self.onQueueChanged = configuration.onQueueChanged
        self.telemetrySink = telemetrySink
    }

    init(
        currentPresentation: ModalPresentation<M>? = nil,
        queuedPresentations: [ModalPresentation<M>] = [],
        configuration: ModalStoreConfiguration<M> = .init(),
        telemetryRecorder: ModalStoreTelemetryRecorder<M>? = nil
    ) {
        let normalizedState = Self.normalize(
            currentPresentation: currentPresentation,
            queuedPresentations: queuedPresentations
        )
        let telemetrySink = ModalStoreTelemetrySink(
            logger: configuration.logger,
            recorder: telemetryRecorder
        )
        self.currentPresentation = normalizedState.current
        self.queuedPresentations = normalizedState.queue
        self.onPresented = configuration.onPresented
        self.onDismissed = configuration.onDismissed
        self.onQueueChanged = configuration.onQueueChanged
        self.telemetrySink = telemetrySink
    }

    public func send(_ intent: ModalIntent<M>) {
        switch intent {
        case .present(let route, let style):
            present(route, style: style)
        case .dismiss:
            dismissCurrent()
        case .dismissAll:
            dismissAll()
        }
    }

    public func present(_ route: M, style: ModalPresentationStyle) {
        let presentation = ModalPresentation(route: route, style: style)
        if currentPresentation == nil {
            currentPresentation = presentation
            telemetrySink.recordPresented(presentation)
            onPresented?(presentation)
        } else {
            let oldQueue = queuedPresentations
            queuedPresentations.append(presentation)
            telemetrySink.recordQueued(presentation)
            telemetrySink.recordQueueChanged(oldQueue: oldQueue, newQueue: queuedPresentations)
            onQueueChanged?(oldQueue, queuedPresentations)
        }
    }

    public func dismissCurrent() {
        dismissCurrent(reason: .dismiss)
    }

    func dismissCurrent(reason: ModalDismissalReason) {
        guard let dismissedPresentation = currentPresentation else { return }
        currentPresentation = nil
        telemetrySink.recordDismissed(dismissedPresentation, reason: reason)
        onDismissed?(dismissedPresentation, reason)
        promoteNextPresentationIfNeeded()
    }

    public func dismissAll() {
        let dismissedPresentation = currentPresentation
        let oldQueue = queuedPresentations
        currentPresentation = nil
        queuedPresentations.removeAll()
        if oldQueue != queuedPresentations {
            telemetrySink.recordQueueChanged(oldQueue: oldQueue, newQueue: queuedPresentations)
            onQueueChanged?(oldQueue, queuedPresentations)
        }
        if let dismissedPresentation {
            telemetrySink.recordDismissed(dismissedPresentation, reason: .dismissAll)
            onDismissed?(dismissedPresentation, .dismissAll)
        }
    }

    func binding(for style: ModalPresentationStyle) -> Binding<ModalPresentation<M>?> {
        binding(for: [style])
    }

    func binding(for styles: Set<ModalPresentationStyle>) -> Binding<ModalPresentation<M>?> {
        Binding(
            get: { [self] in
                guard let currentPresentation, styles.contains(currentPresentation.style) else { return nil }
                return currentPresentation
            },
            set: { [self] newValue in
                guard newValue == nil else { return }
                self.dismissCurrent(reason: .systemDismiss)
            }
        )
    }

    private func promoteNextPresentationIfNeeded() {
        guard currentPresentation == nil, !queuedPresentations.isEmpty else { return }
        let oldQueue = queuedPresentations
        let promotedPresentation = queuedPresentations.removeFirst()
        currentPresentation = promotedPresentation
        telemetrySink.recordQueueChanged(oldQueue: oldQueue, newQueue: queuedPresentations)
        onQueueChanged?(oldQueue, queuedPresentations)
        telemetrySink.recordPresented(promotedPresentation)
        onPresented?(promotedPresentation)
    }

    private static func normalize(
        currentPresentation: ModalPresentation<M>?,
        queuedPresentations: [ModalPresentation<M>]
    ) -> (current: ModalPresentation<M>?, queue: [ModalPresentation<M>]) {
        guard currentPresentation == nil, let firstQueued = queuedPresentations.first else {
            return (currentPresentation, queuedPresentations)
        }

        return (firstQueued, Array(queuedPresentations.dropFirst()))
    }
}
